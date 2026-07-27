package org.jboss.as.quickstarts.kitchensink.model;

import java.io.Serializable;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Demo credentials for a Member (dashboard 12). Password is plain text on purpose —
 * this is a monitoring lab app, not a real IdP.
 */
@SuppressWarnings("serial")
@Entity
@Table(name = "AuthAccount")
public class AuthAccount implements Serializable {

    public static final String DEFAULT_PASSWORD = "demo";

    @Id
    @Column(name = "member_id")
    private Long memberId;

    @Column(nullable = false, length = 64)
    private String password;

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
}
