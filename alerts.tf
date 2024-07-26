locals {
  folders = toset(distinct([for rule in var.alert_rules : rule.folder_name]))
  alerts = { for member in local.folders : member => [for rule in var.alert_rules : merge(rule, {
    expr : coalesce(rule.expr, "${rule.metric_function}(${rule.metric_name}${(rule.filters != null && length(rule.filters) > 0) ? format("{%s}", replace(join(", ", [for k, v in rule.filters : "${k}=\"${v}\""]), "\"", "\\\"")) : ""}${rule.metric_interval})")
  }) if rule.folder_name == member] }
  comparison_operators = {
    gte : ">=",
    gt : ">",
    lt : "<",
    lte : "<=",
    e : "="
  }
}

resource "grafana_folder" "rule_folder" {
  for_each = local.folders
  title    = each.key
}

resource "grafana_rule_group" "alert_rule" {
  for_each = local.alerts

  name             = "${each.key} Group"
  folder_uid       = grafana_folder.rule_folder[each.key].uid
  interval_seconds = var.alert_interval_seconds
  org_id           = 1
  dynamic "rule" {
    for_each = each.value
    content {
      name           = rule.value["name"]
      for            = "0"
      condition      = "C"
      no_data_state  = lookup(rule.value, "no_data_state", "NoData")
      exec_err_state = lookup(rule.value, "exec_err_state", "Error")
      annotations = {
        "Managed By" = "Terraform"
        "Summary"    = lookup(rule.value, "summary", rule.value.name)
      }
      labels = {
        "priority" = lookup(rule.value, "priority", "P2")
      }
      is_paused = false
      data {
        ref_id     = "A"
        query_type = ""
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = rule.value.datasource
        model          = <<EOT
{
    "editorMode": "code",
    "expr": "${rule.value.expr}",
    "hide": false,
    "intervalMs": "1000",
    "legendFormat": "__auto",
    "maxDataPoints": "43200",
    "range": true,
    "refId": "A"
}
EOT
      }
      data {
        ref_id     = "B"
        query_type = ""
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model          = <<EOT
{
    "conditions": [
        {
        "evaluator": {
            "params": [
            0,
            0
            ],
            "type": "gt"
        },
        "operator": {
            "type": "and"
        },
        "query": {
            "params": []
        },
        "reducer": {
            "params": [],
            "type": "last"
        },
        "type": "query"
        }
    ],
    "datasource": {
        "name": "Expression",
        "type": "__expr__",
        "uid": "__expr__"
    },
    "expression": "A",
    "intervalMs": 1000,
    "maxDataPoints": 43200,
    "reducer": "${rule.value.function}",
    "refId": "B",
    "type": "reduce",
    "settings": {
        "mode": "${rule.value.settings_mode}",
        "replaceWithValue": ${rule.value.settings_replaceWith}
    }
}
EOT
      }
      data {
        ref_id     = "C"
        query_type = ""
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model          = <<EOT
{
    "conditions": [
        {
        "evaluator": {
            "params": [
            0,
            0
            ],
            "type": "gt"
        },
        "operator": {
            "type": "and"
        },
        "query": {
            "params": []
        },
        "reducer": {
            "params": [],
            "type": "last"
        },
        "type": "query"
        }
    ],
    "datasource": {
        "name": "Expression",
        "type": "__expr__",
        "uid": "__expr__"
    },
    "expression": "$B ${local.comparison_operators[rule.value.equation]} ${rule.value.threshold}",
    "hide": false,
    "intervalMs": 1000,
    "maxDataPoints": 43200,
    "refId": "C",
    "type": "math"
}
EOT
      }
    }
  }
}







variable "alert_interval_seconds" {
  type        = number
  default     = 10
  description = "The interval, in seconds, at which all rules in the group are evaluated. If a group contains many rules, the rules are evaluated sequentially."
}

variable "alert_rules" {
  type = list(object({
    name                 = string                          # The name of the alert rule
    no_data_state        = optional(string, "NoData")      # Describes what state to enter when the rule's query returns No Data
    exec_err_state       = optional(string, "Error")       # Describes what state to enter when the rule's query is invalid and the rule cannot be executed
    summary              = optional(string, "")            # Rule annotation as a summary
    priority             = optional(string, "P2")          # Rule priority level: P2 is for non-critical alerts, P1 will be set for critical alerts
    folder_name          = optional(string, "Main Alerts") # Grafana folder name in which the rule will be created
    datasource           = string                          # Name of the datasource used for the alert
    expr                 = optional(string, null)          # Full expression for the alert
    metric_name          = optional(string, "")            # Prometheus metric name which queries the data for the alert
    metric_function      = optional(string, "")            # Prometheus function used with metric for queries, like rate, sum etc.
    metric_interval      = optional(string, "")            # The time interval with using functions like rate
    settings_mode        = optional(string, "replaceNN")   # The mode used in B block, possible values are Strict, replaceNN, dropNN
    settings_replaceWith = optional(number, 0)             # The value by which NaN results of the query will be replaced
    filters              = optional(any, {})               # Filters object to identify each service for alerting
    function             = optional(string, "mean")        # One of Reduce functions which will be used in B block for alerting
    equation             = string                          # The equation in the math expression which compares B blocks value with a number and generates an alert if needed. Possible values: gt, lt, gte, lte, e
    threshold            = number                          # The value against which B blocks are compared in the math expression
  }))
  default     = []
  description = "This varibale describes alert folders, groups and rules."
}
