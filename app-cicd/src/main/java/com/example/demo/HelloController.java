package com.example.demo;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Primary REST controller that backs the DevSecOps demo workload.
 * Handles the authenticated greeting experience fronted by the ALB+Cognito
 * integration and exposes a lightweight health endpoint for Kubernetes probes.
 */
@RestController
@Tag(name = "Demo Controller", description = "Endpoints for the DevSecOps demo application")
public class HelloController {

    /**
     * Returns a greeting payload and, when available, echoes the authenticated user identity
     * injected by the ALB's OIDC integration (`x-amzn-oidc-identity` header).
     *
     * @param request HTTP servlet request carrying potential identity headers
     * @return JSON payload containing a greeting, timestamp, and optional authenticated user
     */
    @Operation(summary = "Greeting endpoint",
            description = "Returns metadata about the caller and the AWS-native DevSecOps demo.",
            responses = {
                @ApiResponse(responseCode = "200", description = "Greeting produced",
                        content = @Content(mediaType = "application/json",
                                schema = @Schema(implementation = Map.class)))
            })
    @GetMapping("/")
    public ResponseEntity<Map<String, String>> hello(HttpServletRequest request) {
        Map<String, String> payload = new HashMap<>();
        payload.put("message", "Hello from the AWS-native DevSecOps demo platform");
        payload.put("timestamp", Instant.now().toString());

        String oidcIdentity = request.getHeader("x-amzn-oidc-identity");
        if (oidcIdentity != null && !oidcIdentity.isEmpty()) {
            String sanitized = oidcIdentity.replaceAll("[^a-zA-Z0-9@._-]", "");
            if (!sanitized.isEmpty() && sanitized.length() <= 256) {
                payload.put("authenticatedUser", sanitized);
            }
        }

        return ResponseEntity.ok(payload);
    }

    /**
     * Lightweight readiness/liveness endpoint consumed by Kubernetes probes and ALB health checks.
     *
     * @return 200 OK with the literal string {@code ok}
     */
    @Operation(summary = "Health check", description = "Used by Kubernetes readiness/liveness probes.",
            responses = {
                @ApiResponse(responseCode = "200", description = "Service is healthy",
                        content = @Content(mediaType = "text/plain"))
            })
    @GetMapping("/healthz")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("ok");
    }
}
