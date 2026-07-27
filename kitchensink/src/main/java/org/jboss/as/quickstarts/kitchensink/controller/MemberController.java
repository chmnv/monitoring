/*
 * JBoss, Home of Professional Open Source
 * Copyright 2015, Red Hat, Inc. and/or its affiliates, and individual
 * contributors by the @authors tag. See the copyright.txt in the
 * distribution for a full listing of individual contributors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.jboss.as.quickstarts.kitchensink.controller;

import jakarta.annotation.PostConstruct;
import jakarta.enterprise.inject.Model;
import jakarta.enterprise.inject.Produces;
import jakarta.faces.application.FacesMessage;
import jakarta.faces.context.FacesContext;
import jakarta.inject.Inject;
import jakarta.inject.Named;

import org.jboss.as.quickstarts.kitchensink.metrics.AppMetrics;
import org.jboss.as.quickstarts.kitchensink.model.Member;
import org.jboss.as.quickstarts.kitchensink.service.MemberRegistration;
import org.jboss.as.quickstarts.kitchensink.util.KitchensinkMessages;

@Model
public class MemberController {

    @Inject
    private FacesContext facesContext;

    @Inject
    private MemberRegistration memberRegistration;

    @Produces
    @Named
    private Member newMember;

    /** Shown after a successful registration (dashboard 13). */
    private String lastActivationToken;
    private String lastRegisteredEmail;

    @PostConstruct
    public void initNewMember() {
        newMember = new Member();
    }

    public String getLastActivationToken() {
        return lastActivationToken;
    }

    public String getLastRegisteredEmail() {
        return lastRegisteredEmail;
    }

    public boolean isJustRegistered() {
        return lastActivationToken != null && !lastActivationToken.isBlank();
    }

    public void register() throws Exception {
        AppMetrics.ATTEMPTS.inc();
        try {
            String email = newMember.getEmail();
            String token = memberRegistration.register(newMember);
            lastRegisteredEmail = email;
            lastActivationToken = token;

            FacesMessage m = new FacesMessage(FacesMessage.SEVERITY_INFO,
                    "Registered — account is PENDING",
                    "Copy the activation token below, open Activate, then log in with password demo.");
            facesContext.addMessage(null, m);
            initNewMember();
        } catch (Exception e) {
            lastActivationToken = null;
            lastRegisteredEmail = null;
            AppMetrics.FAILURES.labelValues("error").inc();
            String errorMessage = getRootErrorMessage(e);
            FacesMessage m = new FacesMessage(FacesMessage.SEVERITY_ERROR, errorMessage,
                    KitchensinkMessages.MESSAGES.registerFailMessage());
            facesContext.addMessage(null, m);
        }
    }

    private String getRootErrorMessage(Exception e) {
        String errorMessage = KitchensinkMessages.MESSAGES.defaultErrorMessage();
        if (e == null) {
            return errorMessage;
        }
        Throwable t = e;
        while (t != null) {
            errorMessage = t.getLocalizedMessage();
            t = t.getCause();
        }
        return errorMessage;
    }
}
