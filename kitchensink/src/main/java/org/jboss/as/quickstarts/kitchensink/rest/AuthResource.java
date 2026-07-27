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

/**
 * Application login / logout / session for dashboard 12.
 * Uses HTTP sessions — distinct from WildFly management audit (dashboard 08).
 */
@Path("/auth")
@RequestScoped
public class AuthResource {

    public static final String SESSION_MEMBER_ID = "kitchensink.memberId";
    public static final String SESSION_EMAIL = "kitchensink.email";
    public static final String SESSION_LOGIN_AT = "kitchensink.loginAt";
    public static final String SESSION_COUNTED = "kitchensink.sessionCounted";

    @Inject
    private Logger log;

    @Inject
    private MemberRepository repository;

    @Inject
    private EntityManager em;

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

            HttpSession previous = request.getSession(false);
            if (previous != null) {
                // Re-login: destroy old session so listener adjusts the gauge.
                previous.invalidate();
            }

            HttpSession session = request.getSession(true);
            session.setAttribute(SESSION_MEMBER_ID, member.getId());
            session.setAttribute(SESSION_EMAIL, member.getEmail());
            session.setAttribute(SESSION_LOGIN_AT, System.currentTimeMillis());
            session.setAttribute(SESSION_COUNTED, Boolean.TRUE);
            AppMetrics.ACTIVE_SESSIONS.inc();

            AppMetrics.AUTH_ATTEMPTS.labelValues("success").inc();
            Map<String, Object> ok = new HashMap<>();
            ok.put("status", "ok");
            ok.put("memberId", member.getId());
            ok.put("email", member.getEmail());
            ok.put("name", member.getName());
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
            // Gauge decrement happens in AuthSessionListener on destroy.
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
        return Response.ok(body).build();
    }
}
