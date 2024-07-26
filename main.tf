resource "grafana_notification_policy" "policy" {
  contact_point   = var.notifications.contact_point
  group_by        = var.notifications.group_by
  group_interval  = var.notifications.group_interval
  repeat_interval = var.notifications.repeat_interval

  dynamic "policy" {
    for_each = var.notifications.policy != null ? [1] : []

    content {
      contact_point = var.notifications.policy.contact_point
      continue      = var.notifications.policy.continue
      group_by      = var.notifications.policy.group_by
      mute_timings  = var.notifications.policy.mute_timings

      dynamic "matcher" {
        for_each = var.notifications.policy.matcher.label != null ? [1] : [0]

        content {
          label = var.notifications.policy.matcher.label
          match = var.notifications.policy.matcher.match
          value = var.notifications.policy.matcher.value
        }
      }
    }
  }
}


variable "notifications" {
  type = object({
    contact_point   = optional(string, "Email")                                 # The default contact point to route all unmatched notifications to.
    group_by        = optional(list(string), ["grafana_folder", "alertname"])   # A list of alert labels to group alerts into notifications by.
    group_interval  = optional(string, "5m")                                    # Minimum time interval between two notifications for the same group.
    repeat_interval = optional(string, "4h")                                    # Minimum time interval for re-sending a notification if an alert is still firing.

    policy = optional(object({
      contact_point = optional(string, null) # The contact point to route notifications that match this rule to.
      continue      = optional(bool, false)  # Whether to continue matching subsequent rules if an alert matches the current rule. Otherwise, the rule will be 'consumed' by the first policy to match it.
      group_by      = optional(list(string), [])
      mute_timings  = optional(list(string), []) # A list of mute timing names to apply to alerts that match this policy.

      matcher = optional(object({
        label = optional(string, "priority") # The name of the label to match against.
        match = optional(string, "=")        # The operator to apply when matching values of the given label. Allowed operators are = for equality, != for negated equality, =~ for regex equality, and !~ for negated regex equality.
        value = optional(string, "P1")       # The label value to match against.
      }))
    }))
  })
  description = "Represents the configuration options for Grafana notification policies."
  default     = {}
}
