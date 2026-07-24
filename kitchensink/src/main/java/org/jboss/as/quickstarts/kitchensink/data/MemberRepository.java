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
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.jboss.as.quickstarts.kitchensink.data;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Root;
import java.util.List;

import org.jboss.as.quickstarts.kitchensink.metrics.AppMetrics;
import org.jboss.as.quickstarts.kitchensink.model.Member;

@ApplicationScoped
public class MemberRepository {

    @Inject
    private EntityManager em;

    public Member findById(Long id) {
        long start = System.nanoTime();
        try {
            return em.find(Member.class, id);
        } finally {
            observe("findById", start);
        }
    }

    public Member findByEmail(String email) {
        long start = System.nanoTime();
        try {
            CriteriaBuilder cb = em.getCriteriaBuilder();
            CriteriaQuery<Member> criteria = cb.createQuery(Member.class);
            Root<Member> member = criteria.from(Member.class);
            criteria.select(member).where(cb.equal(member.get("email"), email));
            return em.createQuery(criteria).getSingleResult();
        } finally {
            observe("findByEmail", start);
        }
    }

    public List<Member> findAllOrderedByName() {
        long start = System.nanoTime();
        try {
            CriteriaBuilder cb = em.getCriteriaBuilder();
            CriteriaQuery<Member> criteria = cb.createQuery(Member.class);
            Root<Member> member = criteria.from(Member.class);
            criteria.select(member).orderBy(cb.asc(member.get("name")));
            return em.createQuery(criteria).getResultList();
        } finally {
            observe("findAll", start);
        }
    }

    /** Total members in the DB — used to seed the kitchensink_members gauge on startup. */
    public long countAll() {
        long start = System.nanoTime();
        try {
            return em.createQuery("select count(m) from Member m", Long.class).getSingleResult();
        } finally {
            observe("countAll", start);
        }
    }

    private static void observe(String operation, long startNanos) {
        AppMetrics.DB_OPERATION.labelValues(operation)
                .observe((System.nanoTime() - startNanos) / 1_000_000_000.0);
    }
}
