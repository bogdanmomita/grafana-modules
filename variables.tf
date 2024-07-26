variable "email_endpoints" {
  type = list(object({
    name                    = string                                                 # The name of the contact point.
    to                      = list(string)                                           # List of email addresses to send the alert to.
    from                    = string                                                 # The email address to send the alert from.
    smtp_smarthost          = string                                                 # The SMTP server to use for sending emails.
    smtp_auth_username      = optional(string, "")                                   # The SMTP username for authentication.
    smtp_auth_password      = optional(string, "")                                   # The SMTP password for authentication.
    smtp_auth_identity      = optional(string, "")                                   # The SMTP identity for authentication.
    smtp_require_tls        = optional(bool, true)                                   # Whether to use TLS for SMTP.
    html                    = optional(string, "")                                   # Templated HTML content of the email.
    text                    = optional(string, "")                                   # Templated text content of the email.
    headers                 = optional(map(string), {})                              # Optional custom email headers.
    disable_resolve_message = optional(bool, false)                                  # Whether to disable sending resolve messages.
  }))
  default     = []
  description = "Email contact points list."
}


variable "webhook_endpoints" {
  type = list(object({
    name                    = string                                                 # The name of the contact point.
    url                     = string                                                 # The webhook URL to send alerts to.
    http_config             = optional(object({                                      # Optional HTTP configuration.
      bearer_token          = optional(string, "")                                   # Optional bearer token for authentication.
      basic_auth            = optional(object({
        username            = string                                                 # Basic auth username.
        password            = string                                                 # Basic auth password.
      }), null)
      tls_config            = optional(object({
        ca_file             = optional(string, "")                                   # Path to the CA file.
        cert_file           = optional(string, "")                                   # Path to the cert file.
        key_file            = optional(string, "")                                   # Path to the key file.
        insecure_skip_verify = optional(bool, false)                                 # Whether to skip TLS verification.
      }), null)
    }), null)
    send_resolved           = optional(bool, false)                                  # Whether to send resolved alerts.
  }))
  default     = []
  description = "Webhook contact points list."
}
