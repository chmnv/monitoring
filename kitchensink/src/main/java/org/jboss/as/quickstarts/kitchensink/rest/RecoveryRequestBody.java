package org.jboss.as.quickstarts.kitchensink.rest;

/**
 * JSON body for POST /rest/auth/recovery/request.
 */
public class RecoveryRequestBody {

    private String email;

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }
}
