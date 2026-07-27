package org.jboss.as.quickstarts.kitchensink.service;

import org.jboss.as.quickstarts.kitchensink.metrics.AppMetrics;
import org.jboss.as.quickstarts.kitchensink.model.AuthAccount;
import org.jboss.as.quickstarts.kitchensink.model.Member;

import jakarta.annotation.Resource;
import jakarta.ejb.Stateless;
import jakarta.enterprise.event.Event;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Status;
import jakarta.transaction.Synchronization;
import jakarta.transaction.TransactionSynchronizationRegistry;
import java.util.logging.Logger;

/**
 * Registers a Member and creates a pending AuthAccount with an activation token
 * (dashboard 13). Login (dashboard 12) requires status=activated.
 */
@Stateless
public class MemberRegistration {

    @Inject
    private Logger log;

    @Inject
    private EntityManager em;

    @Inject
    private Event<Member> memberEventSrc;

    @Resource
    private TransactionSynchronizationRegistry txSync;

    /**
     * Persist member + pending auth account. Returns the activation token (demo only).
     */
    public String register(Member member) throws Exception {
        long startNanos = System.nanoTime();
        log.info("Registering " + member.getName());
        em.persist(member);
        em.flush();

        String token = AuthAccount.newToken();
        AuthAccount account = new AuthAccount();
        account.setMemberId(member.getId());
        account.setPassword(AuthAccount.DEFAULT_PASSWORD);
        account.setStatus(AuthAccount.STATUS_PENDING);
        account.setRole(AuthAccount.ROLE_MEMBER);
        account.setActivationToken(token);
        account.setTokenExpiresAt(System.currentTimeMillis() + AuthAccount.TOKEN_TTL_MS);
        em.persist(account);

        memberEventSrc.fire(member);

        final double persistSeconds = (System.nanoTime() - startNanos) / 1_000_000_000.0;
        AppMetrics.DB_OPERATION.labelValues("persist").observe(persistSeconds);

        txSync.registerInterposedSynchronization(new Synchronization() {
            @Override
            public void beforeCompletion() {
                // no-op
            }

            @Override
            public void afterCompletion(int status) {
                if (status != Status.STATUS_COMMITTED) {
                    return;
                }
                double totalSeconds = (System.nanoTime() - startNanos) / 1_000_000_000.0;
                AppMetrics.DURATION.observe(totalSeconds);
                AppMetrics.REGISTRATIONS.inc();
                AppMetrics.MEMBERS.inc();
                AppMetrics.ACCOUNTS_PENDING.inc();
            }
        });

        return token;
    }
}
