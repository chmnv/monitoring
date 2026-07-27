package org.jboss.as.quickstarts.kitchensink.model;

import java.io.Serializable;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Demo credentials + activation/recovery/role state for a Member (dashboards 12–15).
 * Password is plain text on purpose — monitoring lab app, not a real IdP.
 */
@SuppressWarnings("serial")
@Entity
@Table(name = "AuthAccount")
public class AuthAccount implements Serializable {

    public static final String DEFAULT_PASSWORD = "demo";
    public static final String STATUS_PENDING = "pending";
    public static final String STATUS_ACTIVATED = "activated";

    public static final String ROLE_MEMBER = "member";
    public static final String ROLE_ADMIN = "admin";

    /** Demo token lifetime (1 hour). Load script can force-expire via expire helpers. */
    public static final long TOKEN_TTL_MS = 60L * 60L * 1000L;

    @Id
    @Column(name = "member_id")
    private Long memberId;

    @Column(nullable = false, length = 64)
    private String password;

    @Column(nullable = false, length = 32)
    private String status = STATUS_PENDING;

    @Column(name = "app_role", nullable = false, length = 32)
    private String role = ROLE_MEMBER;

    @Column(name = "activation_token", length = 64)
    private String activationToken;

    @Column(name = "token_expires_at")
    private Long tokenExpiresAt;

    @Column(name = "activated_at")
    private Long activatedAt;

    @Column(name = "recovery_token", length = 64)
    private String recoveryToken;

    @Column(name = "recovery_expires_at")
    private Long recoveryExpiresAt;

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

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public boolean isAdmin() {
        return ROLE_ADMIN.equals(role);
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

    public String getRecoveryToken() {
        return recoveryToken;
    }

    public void setRecoveryToken(String recoveryToken) {
        this.recoveryToken = recoveryToken;
    }

    public Long getRecoveryExpiresAt() {
        return recoveryExpiresAt;
    }

    public void setRecoveryExpiresAt(Long recoveryExpiresAt) {
        this.recoveryExpiresAt = recoveryExpiresAt;
    }

    public boolean isRecoveryExpired(long nowMs) {
        return recoveryExpiresAt != null && nowMs > recoveryExpiresAt;
    }

    public boolean hasOpenRecovery() {
        return recoveryToken != null && !recoveryToken.isBlank();
    }
}
