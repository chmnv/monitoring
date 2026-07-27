package org.jboss.as.quickstarts.kitchensink.rest;

import java.util.HashMap;
import java.util.Map;
import java.util.logging.Logger;

import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.NoResultException;
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

import org.jboss.as.quickstarts.kitchensink.data.MemberRepository;
import org.jboss.as.quickstarts.kitchensink.metrics.AppMetrics;
import org.jboss.as.quickstarts.kitchensink.model.AuthAccount;
import org.jboss.as.quickstarts.kitchensink.model.Member;
import org.jboss.as.quickstarts.kitchensink.service.AccountActivation;
import org.jboss.as.quickstarts.kitchensink.service.AccountRecovery;

/**
 * Application login / logout / session (dashboard 12), account activation (13),
 * and password recovery (14). Role is stored on session for authorization (15).
 * Distinct from WildFly management audit (dashboard 08).
 */
@Path("/auth")
@RequestScoped
public class AuthResource {

    public static final String SESSION_MEMBER_ID = "kitchensink.memberId";
    public static final String SESSION_EMAIL = "kitchensink.email";
    public static final String SESSION_LOGIN_AT = "kitchensink.loginAt";
    public static final String SESSION_COUNTED = "kitchensink.sessionCounted";
    public static final String SESSION_ROLE = "kitchensink.role";

    @Inject
    private Logger log;

    @Inject
    private MemberRepository repository;

    @Inject
    private EntityManager em;

    @Inject
    private AccountActivation activation;

    @Inject
    private AccountRecovery recovery;

    @POST
    @Path("/login")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response login(LoginRequest body, @Context HttpServletRequest request) {
        long start = System.nanoTime();
        try {
            if (body == null || body.getEmail() == null || body.getEmail().isBlank()) {
                AppMetrics.AUTH_ATTEMPTS.labelValues("error").inc();
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("error", "email required"))
                        .build();
            }
            String email = body.getEmail().trim();
            String password = body.getPassword() == null ? "" : body.getPassword();

            Member member;
            try {
                member = repository.findByEmail(email);
            } catch (NoResultException e) {
                member = null;
            }
            if (member == null) {
                AppMetrics.AUTH_ATTEMPTS.labelValues("unknown_user").inc();
                return Response.status(Response.Status.UNAUTHORIZED)
                        .entity(Map.of("error", "unknown_user"))
                        .build();
            }

            AuthAccount account = em.find(AuthAccount.class, member.getId());
            String expected = account != null ? account.getPassword() : AuthAccount.DEFAULT_PASSWORD;
            if (!expected.equals(password)) {
                AppMetrics.AUTH_ATTEMPTS.labelValues("bad_credentials").inc();
                return Response.status(Response.Status.UNAUTHORIZED)
                        .entity(Map.of("error", "bad_credentials"))
                        .build();
            }

            if (account != null && !account.isActivated()) {
                AppMetrics.AUTH_ATTEMPTS.labelValues("not_activated").inc();
                return Response.status(Response.Status.FORBIDDEN)
                        .entity(Map.of("error", "not_activated", "status", account.getStatus()))
                        .build();
            }

            HttpSession previous = request.getSession(false);
            if (previous != null) {
                previous.invalidate();
            }

            HttpSession session = request.getSession(true);
            String role = account != null && account.getRole() != null
                    ? account.getRole()
                    : AuthAccount.ROLE_MEMBER;
            session.setAttribute(SESSION_MEMBER_ID, member.getId());
            session.setAttribute(SESSION_EMAIL, member.getEmail());
            session.setAttribute(SESSION_LOGIN_AT, System.currentTimeMillis());
            session.setAttribute(SESSION_ROLE, role);
            session.setAttribute(SESSION_COUNTED, Boolean.TRUE);
            AppMetrics.ACTIVE_SESSIONS.inc();

            AppMetrics.AUTH_ATTEMPTS.labelValues("success").inc();
            Map<String, Object> ok = new HashMap<>();
            ok.put("status", "ok");
            ok.put("memberId", member.getId());
            ok.put("email", member.getEmail());
            ok.put("name", member.getName());
            ok.put("role", role);
            return Response.ok(ok).build();
        } catch (Exception e) {
            log.warning("Login failed: " + e.getMessage());
            AppMetrics.AUTH_ATTEMPTS.labelValues("error").inc();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(Map.of("error", e.getMessage() == null ? "error" : e.getMessage()))
                    .build();
        } finally {
            AppMetrics.AUTH_DURATION.observe((System.nanoTime() - start) / 1_000_000_000.0);
        }
    }

    @POST
    @Path("/logout")
    @Produces(MediaType.APPLICATION_JSON)
    public Response logout(@Context HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session != null) {
            session.invalidate();
            AppMetrics.AUTH_LOGOUTS.inc();
        }
        return Response.ok(Map.of("status", "logged_out")).build();
    }

    @GET
    @Path("/session")
    @Produces(MediaType.APPLICATION_JSON)
    public Response session(@Context HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute(SESSION_MEMBER_ID) == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(Map.of("authenticated", false))
                    .build();
        }
        Map<String, Object> body = new HashMap<>();
        body.put("authenticated", true);
        body.put("memberId", session.getAttribute(SESSION_MEMBER_ID));
        body.put("email", session.getAttribute(SESSION_EMAIL));
        body.put("loginAt", session.getAttribute(SESSION_LOGIN_AT));
        body.put("role", session.getAttribute(SESSION_ROLE));
        return Response.ok(body).build();
    }

    /**
     * Activate a pending account with the token returned at registration (dashboard 13).
     */
    @POST
    @Path("/activate")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response activate(ActivateRequest body) {
        long start = System.nanoTime();
        try {
            if (body == null || body.getToken() == null || body.getToken().isBlank()) {
                AppMetrics.ACTIVATION_ATTEMPTS.labelValues("error").inc();
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("error", "token required"))
                        .build();
            }
            AccountActivation.Result result = activation.activate(body.getToken().trim());
            switch (result.outcome) {
                case SUCCESS:
                    AppMetrics.ACTIVATION_ATTEMPTS.labelValues("success").inc();
                    Map<String, Object> ok = new HashMap<>();
                    ok.put("status", "activated");
                    ok.put("memberId", result.memberId);
                    return Response.ok(ok).build();
                case INVALID_TOKEN:
                    AppMetrics.ACTIVATION_ATTEMPTS.labelValues("invalid_token").inc();
                    return Response.status(Response.Status.NOT_FOUND)
                            .entity(Map.of("error", "invalid_token"))
                            .build();
                case EXPIRED:
                    AppMetrics.ACTIVATION_ATTEMPTS.labelValues("expired").inc();
                    return Response.status(Response.Status.GONE)
                            .entity(Map.of("error", "expired"))
                            .build();
                case ALREADY_ACTIVATED:
                    AppMetrics.ACTIVATION_ATTEMPTS.labelValues("already_activated").inc();
                    return Response.status(Response.Status.CONFLICT)
                            .entity(Map.of("error", "already_activated"))
                            .build();
                default:
                    AppMetrics.ACTIVATION_ATTEMPTS.labelValues("error").inc();
                    return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                            .entity(Map.of("error", "error"))
                            .build();
            }
        } catch (Exception e) {
            log.warning("Activation failed: " + e.getMessage());
            AppMetrics.ACTIVATION_ATTEMPTS.labelValues("error").inc();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(Map.of("error", e.getMessage() == null ? "error" : e.getMessage()))
                    .build();
        } finally {
            AppMetrics.ACTIVATION_DURATION.observe((System.nanoTime() - start) / 1_000_000_000.0);
        }
    }

    /**
     * Demo-only helper: force a pending token to expire so load traffic can hit outcome=expired.
     */
    @POST
    @Path("/activation/expire")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response expireToken(ActivateRequest body) {
        if (body == null || body.getToken() == null || body.getToken().isBlank()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(Map.of("error", "token required"))
                    .build();
        }
        AccountActivation.Result result = activation.expireForDemo(body.getToken().trim());
        if (result.outcome == AccountActivation.Outcome.INVALID_TOKEN) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(Map.of("error", "invalid_token"))
                    .build();
        }
        return Response.ok(Map.of("status", "expired_for_demo", "memberId", result.memberId)).build();
    }

    /**
     * Start password recovery: issue a reset token for an activated account (dashboard 14).
     */
    @POST
    @Path("/recovery/request")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response recoveryRequest(RecoveryRequestBody body) {
        try {
            if (body == null || body.getEmail() == null || body.getEmail().isBlank()) {
                AppMetrics.RECOVERY_REQUESTS.labelValues("error").inc();
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("error", "email required"))
                        .build();
            }
            AccountRecovery.RequestResult result = recovery.request(body.getEmail().trim());
            switch (result.outcome) {
                case SUCCESS:
                    AppMetrics.RECOVERY_REQUESTS.labelValues("success").inc();
                    Map<String, Object> ok = new HashMap<>();
                    ok.put("status", "token_issued");
                    ok.put("memberId", result.memberId);
                    ok.put("recoveryToken", result.recoveryToken);
                    return Response.ok(ok).build();
                case UNKNOWN_USER:
                    AppMetrics.RECOVERY_REQUESTS.labelValues("unknown_user").inc();
                    return Response.status(Response.Status.NOT_FOUND)
                            .entity(Map.of("error", "unknown_user"))
                            .build();
                case NOT_ACTIVATED:
                    AppMetrics.RECOVERY_REQUESTS.labelValues("not_activated").inc();
                    return Response.status(Response.Status.FORBIDDEN)
                            .entity(Map.of("error", "not_activated"))
                            .build();
                default:
                    AppMetrics.RECOVERY_REQUESTS.labelValues("error").inc();
                    return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                            .entity(Map.of("error", "error"))
                            .build();
            }
        } catch (Exception e) {
            log.warning("Recovery request failed: " + e.getMessage());
            AppMetrics.RECOVERY_REQUESTS.labelValues("error").inc();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(Map.of("error", e.getMessage() == null ? "error" : e.getMessage()))
                    .build();
        }
    }

    /**
     * Consume a recovery token and set a new password (dashboard 14).
     */
    @POST
    @Path("/recovery/reset")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response recoveryReset(RecoveryResetBody body) {
        long start = System.nanoTime();
        try {
            if (body == null || body.getToken() == null || body.getToken().isBlank()) {
                AppMetrics.RECOVERY_RESETS.labelValues("error").inc();
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("error", "token required"))
                        .build();
            }
            String password = body.getPassword() == null ? "" : body.getPassword();
            if (password.isBlank()) {
                AppMetrics.RECOVERY_RESETS.labelValues("error").inc();
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("error", "password required"))
                        .build();
            }
            AccountRecovery.ResetResult result = recovery.reset(body.getToken().trim(), password);
            switch (result.outcome) {
                case SUCCESS:
                    AppMetrics.RECOVERY_RESETS.labelValues("success").inc();
                    Map<String, Object> ok = new HashMap<>();
                    ok.put("status", "password_reset");
                    ok.put("memberId", result.memberId);
                    return Response.ok(ok).build();
                case INVALID_TOKEN:
                    AppMetrics.RECOVERY_RESETS.labelValues("invalid_token").inc();
                    return Response.status(Response.Status.NOT_FOUND)
                            .entity(Map.of("error", "invalid_token"))
                            .build();
                case EXPIRED:
                    AppMetrics.RECOVERY_RESETS.labelValues("expired").inc();
                    return Response.status(Response.Status.GONE)
                            .entity(Map.of("error", "expired"))
                            .build();
                default:
                    AppMetrics.RECOVERY_RESETS.labelValues("error").inc();
                    return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                            .entity(Map.of("error", "error"))
                            .build();
            }
        } catch (Exception e) {
            log.warning("Recovery reset failed: " + e.getMessage());
            AppMetrics.RECOVERY_RESETS.labelValues("error").inc();
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(Map.of("error", e.getMessage() == null ? "error" : e.getMessage()))
                    .build();
        } finally {
            AppMetrics.RECOVERY_DURATION.observe((System.nanoTime() - start) / 1_000_000_000.0);
        }
    }

    /**
     * Demo-only helper: force a recovery token to expire so load traffic can hit outcome=expired.
     */
    @POST
    @Path("/recovery/expire")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response recoveryExpire(RecoveryResetBody body) {
        if (body == null || body.getToken() == null || body.getToken().isBlank()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(Map.of("error", "token required"))
                    .build();
        }
        AccountRecovery.ResetResult result = recovery.expireForDemo(body.getToken().trim());
        if (result.outcome == AccountRecovery.ResetOutcome.INVALID_TOKEN) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(Map.of("error", "invalid_token"))
                    .build();
        }
        return Response.ok(Map.of("status", "expired_for_demo", "memberId", result.memberId)).build();
    }
}
