package org.jboss.as.quickstarts.kitchensink.rest;

/**
 * JSON body for POST /rest/auth/recovery/reset and /rest/auth/recovery/expire.
 */
public class RecoveryResetBody {

    private String token;
    private String password;

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}
