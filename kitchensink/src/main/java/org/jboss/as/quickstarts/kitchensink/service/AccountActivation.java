package org.jboss.as.quickstarts.kitchensink.service;

import java.util.List;

import jakarta.ejb.Stateless;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;

import org.jboss.as.quickstarts.kitchensink.metrics.AppMetrics;
import org.jboss.as.quickstarts.kitchensink.model.AuthAccount;

/**
 * Account activation for dashboard 13 (container-managed TX).
 */
@Stateless
public class AccountActivation {

    public enum Outcome {
        SUCCESS, INVALID_TOKEN, EXPIRED, ALREADY_ACTIVATED
    }

    public static final class Result {
        public final Outcome outcome;
        public final Long memberId;

        public Result(Outcome outcome, Long memberId) {
            this.outcome = outcome;
            this.memberId = memberId;
        }
    }

    @Inject
    private EntityManager em;

    public Result activate(String token) {
        List<AuthAccount> found = em.createQuery(
                        "select a from AuthAccount a where a.activationToken = :t", AuthAccount.class)
                .setParameter("t", token)
                .setMaxResults(1)
                .getResultList();
        if (found.isEmpty()) {
            return new Result(Outcome.INVALID_TOKEN, null);
        }

        AuthAccount account = found.get(0);
        if (account.isActivated()) {
            return new Result(Outcome.ALREADY_ACTIVATED, account.getMemberId());
        }
        long now = System.currentTimeMillis();
        if (account.isTokenExpired(now)) {
            return new Result(Outcome.EXPIRED, account.getMemberId());
        }

        account.setStatus(AuthAccount.STATUS_ACTIVATED);
        account.setActivatedAt(now);
        // Keep token so a second activate can hit already_activated (demo/load).
        em.merge(account);

        AppMetrics.ACCOUNTS_ACTIVATED.inc();
        AppMetrics.ACCOUNTS_PENDING.dec();
        return new Result(Outcome.SUCCESS, account.getMemberId());
    }

    /** Demo helper: force token expiry for load-script expired outcome. */
    public Result expireForDemo(String token) {
        List<AuthAccount> found = em.createQuery(
                        "select a from AuthAccount a where a.activationToken = :t", AuthAccount.class)
                .setParameter("t", token)
                .setMaxResults(1)
                .getResultList();
        if (found.isEmpty()) {
            return new Result(Outcome.INVALID_TOKEN, null);
        }
        AuthAccount account = found.get(0);
        account.setTokenExpiresAt(System.currentTimeMillis() - 1000L);
        em.merge(account);
        return new Result(Outcome.EXPIRED, account.getMemberId());
    }
}
