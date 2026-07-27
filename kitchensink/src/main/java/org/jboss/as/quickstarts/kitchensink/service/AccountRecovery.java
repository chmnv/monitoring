package org.jboss.as.quickstarts.kitchensink.service;

import java.util.List;

import jakarta.ejb.Stateless;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.NoResultException;

import org.jboss.as.quickstarts.kitchensink.data.MemberRepository;
import org.jboss.as.quickstarts.kitchensink.metrics.AppMetrics;
import org.jboss.as.quickstarts.kitchensink.model.AuthAccount;
import org.jboss.as.quickstarts.kitchensink.model.Member;

/**
 * Password recovery for dashboard 14 (container-managed TX).
 * Distinct from login (12) and activation (13).
 */
@Stateless
public class AccountRecovery {

    public enum RequestOutcome {
        SUCCESS, UNKNOWN_USER, NOT_ACTIVATED
    }

    public enum ResetOutcome {
        SUCCESS, INVALID_TOKEN, EXPIRED
    }

    public static final class RequestResult {
        public final RequestOutcome outcome;
        public final Long memberId;
        public final String recoveryToken;

        public RequestResult(RequestOutcome outcome, Long memberId, String recoveryToken) {
            this.outcome = outcome;
            this.memberId = memberId;
            this.recoveryToken = recoveryToken;
        }
    }

    public static final class ResetResult {
        public final ResetOutcome outcome;
        public final Long memberId;

        public ResetResult(ResetOutcome outcome, Long memberId) {
            this.outcome = outcome;
            this.memberId = memberId;
        }
    }

    @Inject
    private EntityManager em;

    @Inject
    private MemberRepository repository;

    public RequestResult request(String email) {
        Member member;
        try {
            member = repository.findByEmail(email);
        } catch (NoResultException e) {
            return new RequestResult(RequestOutcome.UNKNOWN_USER, null, null);
        }

        AuthAccount account = em.find(AuthAccount.class, member.getId());
        if (account == null) {
            // Seeded path without AuthAccount — treat as activated with default password.
            account = new AuthAccount();
            account.setMemberId(member.getId());
            account.setPassword(AuthAccount.DEFAULT_PASSWORD);
            account.setStatus(AuthAccount.STATUS_ACTIVATED);
            account.setActivatedAt(System.currentTimeMillis());
            em.persist(account);
        }

        if (!account.isActivated()) {
            return new RequestResult(RequestOutcome.NOT_ACTIVATED, member.getId(), null);
        }

        boolean hadOpen = account.hasOpenRecovery();
        String token = AuthAccount.newToken();
        account.setRecoveryToken(token);
        account.setRecoveryExpiresAt(System.currentTimeMillis() + AuthAccount.TOKEN_TTL_MS);
        em.merge(account);
        if (!hadOpen) {
            AppMetrics.RECOVERY_PENDING.inc();
        }
        return new RequestResult(RequestOutcome.SUCCESS, member.getId(), token);
    }

    public ResetResult reset(String token, String newPassword) {
        List<AuthAccount> found = em.createQuery(
                        "select a from AuthAccount a where a.recoveryToken = :t", AuthAccount.class)
                .setParameter("t", token)
                .setMaxResults(1)
                .getResultList();
        if (found.isEmpty()) {
            return new ResetResult(ResetOutcome.INVALID_TOKEN, null);
        }

        AuthAccount account = found.get(0);
        long now = System.currentTimeMillis();
        if (account.isRecoveryExpired(now)) {
            return new ResetResult(ResetOutcome.EXPIRED, account.getMemberId());
        }

        account.setPassword(newPassword);
        account.setRecoveryToken(null);
        account.setRecoveryExpiresAt(null);
        em.merge(account);

        AppMetrics.RECOVERY_COMPLETED.inc();
        AppMetrics.RECOVERY_PENDING.dec();
        return new ResetResult(ResetOutcome.SUCCESS, account.getMemberId());
    }

    /** Demo helper: force recovery token expiry for load-script expired outcome. */
    public ResetResult expireForDemo(String token) {
        List<AuthAccount> found = em.createQuery(
                        "select a from AuthAccount a where a.recoveryToken = :t", AuthAccount.class)
                .setParameter("t", token)
                .setMaxResults(1)
                .getResultList();
        if (found.isEmpty()) {
            return new ResetResult(ResetOutcome.INVALID_TOKEN, null);
        }
        AuthAccount account = found.get(0);
        account.setRecoveryExpiresAt(System.currentTimeMillis() - 1000L);
        em.merge(account);
        return new ResetResult(ResetOutcome.EXPIRED, account.getMemberId());
    }
}
