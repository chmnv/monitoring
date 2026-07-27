/*
 * JBoss, Home of Professional Open Source
 * Copyright 2015, Red Hat, Inc. and/or its affiliates, and individual
 * contributors by the @authors tag. See the copyright.txt in the
 * distribution for a full listing of individual contributors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
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

// The @Stateless annotation eliminates the need for manual transaction demarcation
@Stateless
public class MemberRegistration {

    @Inject
    private Logger log;

    @Inject
    private EntityManager em;

    @Inject
    private Event<Member> memberEventSrc;

    /**
     * Used so success counters / gauges move only after a committed TX — not after
     * persist() while rollback is still possible.
     */
    @Resource
    private TransactionSynchronizationRegistry txSync;

    public void register(Member member) throws Exception {
        long startNanos = System.nanoTime();
        log.info("Registering " + member.getName());
        em.persist(member);
        // Force the INSERT now so DB_OPERATION{persist} includes real SQL, not only
        // "add to persistence context" time (INSERT normally waits until flush/commit).
        em.flush();

        // Demo login credentials for dashboard 12 (password always "demo").
        AuthAccount account = new AuthAccount();
        account.setMemberId(member.getId());
        account.setPassword(AuthAccount.DEFAULT_PASSWORD);
        em.persist(account);

        memberEventSrc.fire(member);

        final double persistSeconds = (System.nanoTime() - startNanos) / 1_000_000_000.0;
        AppMetrics.DB_OPERATION.labelValues("persist").observe(persistSeconds);

        // Business success metrics only after commit succeeds.
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
            }
        });
    }
}
