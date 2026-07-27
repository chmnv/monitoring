package org.jboss.as.quickstarts.kitchensink.rest;

import java.util.HashMap;
import java.util.Map;
import java.util.logging.Logger;

import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import org.jboss.as.quickstarts.kitchensink.metrics.AppMetrics;
import org.jboss.as.quickstarts.kitchensink.model.AuthAccount;
import org.jboss.as.quickstarts.kitchensink.service.AdminOperations;

/**
 * Privileged application operations gated by session role (dashboard 15).
 * Distinct from WildFly management audit (dashboard 08) and app login (12).
 */
@Path("/admin")
@RequestScoped
public class AdminResource {

    @Inject
    private Logger log;

    @Inject
    private AdminOperations adminOps;

    private static final class Gate {
        final Response deny;
        final Long memberId;
        final String email;
        final String role;

        Gate(Response deny, Long memberId, String email, String role) {
            this.deny = deny;
            this.memberId = memberId;
            this.email = email;
            this.role = role;
        }
    }

    private Gate requireAdmin(HttpServletRequest request, String operation) {
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute(AuthResource.SESSION_MEMBER_ID) == null) {
            AppMetrics.AUTHZ_ATTEMPTS.labelValues("unauthenticated", operation).inc();
            return new Gate(Response.status(Response.Status.UNAUTHORIZED)
                    .entity(Map.of("error", "unauthenticated"))
                    .build(), null, null, null);
        }
        String role = (String) session.getAttribute(AuthResource.SESSION_ROLE);
        if (role == null) {
            role = AuthAccount.ROLE_MEMBER;
        }
        Long memberId = (Long) session.getAttribute(AuthResource.SESSION_MEMBER_ID);
        String email = (String) session.getAttribute(AuthResource.SESSION_EMAIL);
        if (!AuthAccount.ROLE_ADMIN.equals(role)) {
            AppMetrics.AUTHZ_ATTEMPTS.labelValues("denied", operation).inc();
            return new Gate(Response.status(Response.Status.FORBIDDEN)
                    .entity(Map.of("error", "denied", "role", role, "operation", operation))
                    .build(), memberId, email, role);
        }
        return new Gate(null, memberId, email, role);
    }

    @GET
    @Path("/stats")
    @Produces(MediaType.APPLICATION_JSON)
    public Response stats(@Context HttpServletRequest request) {
        long start = System.nanoTime();
        try {
            Gate gate = requireAdmin(request, "stats");
            if (gate.deny != null) {
                return gate.deny;
            }
            Map<String, Object> body = new HashMap<>(adminOps.stats());
            body.put("actor", gate.email);
            AppMetrics.AUTHZ_ATTEMPTS.labelValues("allowed", "stats").inc();
            return Response.ok(body).build();
        } catch (Exception e) {
            log.warning("Admin stats failed: " + e.getMessage());
            AppMetrics.AUTHZ_ATTEMPTS.labelValues("error", "stats").inc();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(Map.of("error", e.getMessage() == null ? "error" : e.getMessage()))
                    .build();
        } finally {
            AppMetrics.AUTHZ_DURATION.labelValues("stats")
                    .observe((System.nanoTime() - start) / 1_000_000_000.0);
        }
    }

    @GET
    @Path("/export")
    @Produces(MediaType.APPLICATION_JSON)
    public Response export(@Context HttpServletRequest request) {
        long start = System.nanoTime();
        try {
            Gate gate = requireAdmin(request, "export");
            if (gate.deny != null) {
                return gate.deny;
            }
            Map<String, Object> body = new HashMap<>(adminOps.exportDirectory());
            body.put("actor", gate.email);
            AppMetrics.AUTHZ_ATTEMPTS.labelValues("allowed", "export").inc();
            return Response.ok(body).build();
        } catch (Exception e) {
            log.warning("Admin export failed: " + e.getMessage());
            AppMetrics.AUTHZ_ATTEMPTS.labelValues("error", "export").inc();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(Map.of("error", e.getMessage() == null ? "error" : e.getMessage()))
                    .build();
        } finally {
            AppMetrics.AUTHZ_DURATION.labelValues("export")
                    .observe((System.nanoTime() - start) / 1_000_000_000.0);
        }
    }

    @POST
    @Path("/role")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response setRole(SetRoleRequest body, @Context HttpServletRequest request) {
        long start = System.nanoTime();
        try {
            Gate gate = requireAdmin(request, "set_role");
            if (gate.deny != null) {
                return gate.deny;
            }
            if (body == null || body.getEmail() == null || body.getEmail().isBlank()
                    || body.getRole() == null || body.getRole().isBlank()) {
                AppMetrics.AUTHZ_ATTEMPTS.labelValues("error", "set_role").inc();
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("error", "email and role required"))
                        .build();
            }
            Map<String, Object> result = adminOps.setRole(
                    body.getEmail().trim(), body.getRole().trim(), gate.memberId);
            if (result == null) {
                AppMetrics.AUTHZ_ATTEMPTS.labelValues("error", "set_role").inc();
                return Response.status(Response.Status.NOT_FOUND)
                        .entity(Map.of("error", "unknown_user"))
                        .build();
            }
            result.put("actor", gate.email);
            AppMetrics.AUTHZ_ATTEMPTS.labelValues("allowed", "set_role").inc();
            return Response.ok(result).build();
        } catch (IllegalArgumentException e) {
            AppMetrics.AUTHZ_ATTEMPTS.labelValues("error", "set_role").inc();
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(Map.of("error", e.getMessage()))
                    .build();
        } catch (IllegalStateException e) {
            AppMetrics.AUTHZ_ATTEMPTS.labelValues("denied", "set_role").inc();
            return Response.status(Response.Status.FORBIDDEN)
                    .entity(Map.of("error", e.getMessage()))
                    .build();
        } catch (Exception e) {
            log.warning("Admin setRole failed: " + e.getMessage());
            AppMetrics.AUTHZ_ATTEMPTS.labelValues("error", "set_role").inc();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(Map.of("error", e.getMessage() == null ? "error" : e.getMessage()))
                    .build();
        } finally {
            AppMetrics.AUTHZ_DURATION.labelValues("set_role")
                    .observe((System.nanoTime() - start) / 1_000_000_000.0);
        }
    }
}
