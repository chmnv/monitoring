package org.jboss.as.quickstarts.kitchensink.util;

import jakarta.servlet.annotation.WebListener;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.HttpSessionEvent;
import jakarta.servlet.http.HttpSessionListener;

import org.jboss.as.quickstarts.kitchensink.metrics.AppMetrics;
import org.jboss.as.quickstarts.kitchensink.rest.AuthResource;

/**
 * Decrements active-session gauge when an authenticated HTTP session times out
 * or is invalidated outside AuthResource.logout.
 */
@WebListener
public class AuthSessionListener implements HttpSessionListener {

    @Override
    public void sessionCreated(HttpSessionEvent se) {
        // counted on successful login only
    }

    @Override
    public void sessionDestroyed(HttpSessionEvent se) {
        HttpSession session = se.getSession();
        try {
            if (Boolean.TRUE.equals(session.getAttribute(AuthResource.SESSION_COUNTED))) {
                AppMetrics.ACTIVE_SESSIONS.dec();
            }
        } catch (IllegalStateException ignored) {
            // session already invalid
        }
    }
}
