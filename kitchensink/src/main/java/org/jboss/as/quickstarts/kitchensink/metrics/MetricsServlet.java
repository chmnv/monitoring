/*
 * Exposes the application's Prometheus metrics at /kitchensink/metrics.
 *
 * Extends the Prometheus client's Jakarta servlet, which serializes the default
 * registry (where AppMetrics registers its meters) into the Prometheus text
 * format. Prometheus scrapes this endpoint as the "kitchensink-app" job.
 */
package org.jboss.as.quickstarts.kitchensink.metrics;

import io.prometheus.metrics.exporter.servlet.jakarta.PrometheusMetricsServlet;
import jakarta.servlet.annotation.WebServlet;

@WebServlet("/metrics")
public class MetricsServlet extends PrometheusMetricsServlet {
    // Default constructor scrapes PrometheusRegistry.defaultRegistry — the same
    // registry AppMetrics registers on. No extra configuration needed.
}
