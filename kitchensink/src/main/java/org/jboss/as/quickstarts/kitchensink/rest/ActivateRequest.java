package org.jboss.as.quickstarts.kitchensink.rest;

/**
 * JSON body for POST /rest/auth/activate and /rest/auth/activation/expire.
 */
public class ActivateRequest {

    private String token;

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }
}
