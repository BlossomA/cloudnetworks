# ─── Azure Budget Alert ───────────────────────────────────────────────────────
# Sends an email alert when spend approaches the Azure for Students credit limit.
# Requires a notification email — set via var.budget_alert_email.

variable "budget_alert_email" {
  description = "Email address to receive budget alerts"
  type        = string
  default     = ""
}

variable "budget_amount_eur" {
  description = "Total budget limit in EUR for the alert threshold"
  type        = number
  default     = 2.5
}

resource "azurerm_consumption_budget_subscription" "lab" {
  count           = var.budget_alert_email != "" ? 1 : 0
  name            = "${var.project_name}-${var.environment}-budget"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.budget_amount_eur
  time_grain      = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
    end_date   = "2026-12-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.budget_alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.budget_alert_email]
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
