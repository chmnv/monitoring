package org.jboss.as.quickstarts.kitchensink.rest;

/**
 * JSON body for POST /rest/admin/role (dashboard 15).
 */
public class SetRoleRequest {

    private String email;
    private String role;

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }
}
