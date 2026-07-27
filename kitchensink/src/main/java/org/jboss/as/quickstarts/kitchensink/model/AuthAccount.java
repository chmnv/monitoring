package org.jboss.as.quickstarts.kitchensink.model;

import java.io.Serializable;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Demo credentials + activation state for a Member (dashboards 12–13).
 * Password is plain text on purpose — monitoring lab app, not a real IdP.
 */
@SuppressWarnings("serial")
@Entity
@Table(name = "AuthAccount")
public class AuthAccount implements Serializable {

    public static final String DEFAULT_PASSWORD = "demo";
    public static final String STATUS_PENDING = "pending";
    public static final String STATUS_ACTIVATED = "activated";

    /** Demo token lifetime (1 hour). Load script can force-expire via /auth/activation/expire. */
    public static final long TOKEN_TTL_MS = 60L * 60L * 1000L;

    @Id
    @Column(name = "member_id")
    private Long memberId;

    @Column(nullable = false, length = 64)
    private String password;

    @Column(nullable = false, length = 32)
    private String status = STATUS_PENDING;

    @Column(name = "activation_token", length = 64)
    private String activationToken;

    @Column(name = "token_expires_at")
    private Long tokenExpiresAt;

    @Column(name = "activated_at")
    private Long activatedAt;

    public static String newToken() {
        return UUID.randomUUID().toString().replace("-", "").substring(0, 16);
    }

    public Long getMemberId() {
        return memberId;
    }

    public void setMemberId(Long memberId) {
        this.memberId = memberId;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getActivationToken() {
        return activationToken;
    }

    public void setActivationToken(String activationToken) {
        this.activationToken = activationToken;
    }

    public Long getTokenExpiresAt() {
        return tokenExpiresAt;
    }

    public void setTokenExpiresAt(Long tokenExpiresAt) {
        this.tokenExpiresAt = tokenExpiresAt;
    }

    public Long getActivatedAt() {
        return activatedAt;
    }

    public void setActivatedAt(Long activatedAt) {
        this.activatedAt = activatedAt;
    }

    public boolean isActivated() {
        return STATUS_ACTIVATED.equals(status);
    }

    public boolean isTokenExpired(long nowMs) {
        return tokenExpiresAt != null && nowMs > tokenExpiresAt;
    }
}
