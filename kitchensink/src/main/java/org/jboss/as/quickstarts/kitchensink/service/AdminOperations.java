package org.jboss.as.quickstarts.kitchensink.service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import jakarta.ejb.Stateless;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.NoResultException;

import org.jboss.as.quickstarts.kitchensink.data.MemberRepository;
import org.jboss.as.quickstarts.kitchensink.metrics.AppMetrics;
import org.jboss.as.quickstarts.kitchensink.model.AuthAccount;
import org.jboss.as.quickstarts.kitchensink.model.Member;

/**
 * Privileged admin operations for dashboard 15 (container-managed TX).
 * Callers must already be authenticated as admin — this service does not check sessions.
 */
@Stateless
public class AdminOperations {

    @Inject
    private EntityManager em;

    @Inject
    private MemberRepository repository;

    public Map<String, Object> stats() {
        long members = repository.countAll();
        long admins = em.createQuery(
                        "select count(a) from AuthAccount a where a.role = :r", Long.class)
                .setParameter("r", AuthAccount.ROLE_ADMIN)
                .getSingleResult();
        long activated = em.createQuery(
                        "select count(a) from AuthAccount a where a.status = :s", Long.class)
                .setParameter("s", AuthAccount.STATUS_ACTIVATED)
                .getSingleResult();
        Map<String, Object> body = new HashMap<>();
        body.put("members", members);
        body.put("admins", admins);
        body.put("activated", activated);
        return body;
    }

    public Map<String, Object> exportDirectory() {
        List<Object[]> rows = em.createQuery(
                        "select m.email, a.role, a.status from Member m, AuthAccount a "
                                + "where m.id = a.memberId order by m.email",
                        Object[].class)
                .setMaxResults(50)
                .getResultList();
        java.util.List<Map<String, String>> entries = new java.util.ArrayList<>();
        for (Object[] row : rows) {
            Map<String, String> e = new HashMap<>();
            e.put("email", String.valueOf(row[0]));
            e.put("role", String.valueOf(row[1]));
            e.put("status", String.valueOf(row[2]));
            entries.add(e);
        }
        return Map.of("count", entries.size(), "entries", entries);
    }

    /**
     * Change another account's role. Returns null if target email unknown.
     */
    public Map<String, Object> setRole(String email, String newRole, Long actorMemberId) {
        if (!AuthAccount.ROLE_ADMIN.equals(newRole) && !AuthAccount.ROLE_MEMBER.equals(newRole)) {
            throw new IllegalArgumentException("role must be admin or member");
        }
        Member member;
        try {
            member = repository.findByEmail(email);
        } catch (NoResultException e) {
            return null;
        }
        AuthAccount account = em.find(AuthAccount.class, member.getId());
        if (account == null) {
            return null;
        }
        // Keep at least one admin: refuse demoting yourself if you are the last admin.
        if (AuthAccount.ROLE_MEMBER.equals(newRole)
                && actorMemberId != null
                && actorMemberId.equals(member.getId())
                && account.isAdmin()) {
            long admins = em.createQuery(
                            "select count(a) from AuthAccount a where a.role = :r", Long.class)
                    .setParameter("r", AuthAccount.ROLE_ADMIN)
                    .getSingleResult();
            if (admins <= 1) {
                throw new IllegalStateException("cannot_demote_last_admin");
            }
        }

        String previous = account.getRole();
        account.setRole(newRole);
        em.merge(account);
        refreshRoleGauges();

        Map<String, Object> body = new HashMap<>();
        body.put("memberId", member.getId());
        body.put("email", member.getEmail());
        body.put("previousRole", previous);
        body.put("role", newRole);
        return body;
    }

    public void refreshRoleGauges() {
        long admins = em.createQuery(
                        "select count(a) from AuthAccount a where a.role = :r", Long.class)
                .setParameter("r", AuthAccount.ROLE_ADMIN)
                .getSingleResult();
        long members = em.createQuery(
                        "select count(a) from AuthAccount a where a.role = :r", Long.class)
                .setParameter("r", AuthAccount.ROLE_MEMBER)
                .getSingleResult();
        AppMetrics.ACCOUNTS_BY_ROLE.labelValues(AuthAccount.ROLE_ADMIN).set(admins);
        AppMetrics.ACCOUNTS_BY_ROLE.labelValues(AuthAccount.ROLE_MEMBER).set(members);
    }
}
