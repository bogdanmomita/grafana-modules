variable "alert_rules" {
  type = list(object({
    name = string
    folder_name = string
    azure_monitor_query = object({
      subscription = string
      metric_namespace = string
      metric_name = string
      aggregation = string
      time_grain = string
      region = string
      resources = list(object({
        resource_group = string
        resource_name = string
      }))
    })
    threshold = number
    time_period = string
    frequency = string
    severity = string
    additional_labels = map(string)
    annotation_description = string
    annotation_summary = string
  }))
  description = "List of Azure Monitor alert rules"
}

variable "azure_monitor_datasource_uid" {
  type = string
  description = "UID of the Azure Monitor data source in Grafana"
}



-----------------------------------------


locals {
  folders = toset(distinct([for rule in var.alert_rules : rule.folder_name]))
  alerts = { for member in local.folders : member => [for rule in var.alert_rules : rule if rule.folder_name == member] }
}

resource "grafana_folder" "rule_folder" {
  for_each = local.folders
  title    = each.key
}

resource "grafana_rule_group" "alert_rule" {
  for_each = local.alerts

  name             = "${each.key} Group"
  folder_uid       = grafana_folder.rule_folder[each.key].uid
  interval_seconds = 60
  org_id           = 1

  dynamic "rule" {
    for_each = each.value
    content {
      name           = rule.value.name
      for            = rule.value.time_period
      condition      = "C"
      no_data_state  = "NoData"
      exec_err_state = "Error"

      annotations = {
        description = rule.value.annotation_description
        summary     = rule.value.annotation_summary
      }

      labels = merge({
        severity = rule.value.severity
      }, rule.value.additional_labels)

      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = var.azure_monitor_datasource_uid
        model = jsonencode({
          azureMonitor = {
            aggregation     = rule.value.azure_monitor_query.aggregation
            metricName      = rule.value.azure_monitor_query.metric_name
            metricNamespace = rule.value.azure_monitor_query.metric_namespace
            region          = rule.value.azure_monitor_query.region
            resources       = rule.value.azure_monitor_query.resources
            timeGrain       = rule.value.azure_monitor_query.time_grain
          }
          queryType    = "Azure Monitor"
          subscription = rule.value.azure_monitor_query.subscription
        })
      }

      data {
        ref_id = "B"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          conditions = [{
            evaluator = { params = [], type = "gt" }
            operator  = { type = "and" }
            query     = { params = ["B"] }
            reducer   = { params = [], type = "last" }
            type      = "query"
          }]
          datasource = { type = "__expr__", uid = "__expr__" }
          expression = "A"
          type       = "reduce"
          reducer    = "last"
        })
      }

      data {
        ref_id = "C"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = "__expr__"
        model = jsonencode({
          conditions = [{
            evaluator = { params = [rule.value.threshold], type = "gt" }
            operator  = { type = "and" }
            query     = { params = ["C"] }
            reducer   = { params = [], type = "last" }
            type      = "query"
          }]
          datasource = { type = "__expr__", uid = "__expr__" }
          expression = "B"
          type       = "threshold"
        })
      }
    }
  }
}


------------------------------

alert_rules = [
  {
    name        = "VM % Used Memory - Guest Metrics"
    folder_name = "FIRST_FOLDER"
    azure_monitor_query = {
      subscription     = "12345-randomid-6789"
      metric_namespace = "microsoft.compute/virtualmachines"
      metric_name      = "\\Memory\\% Committed Bytes In Use"
      aggregation      = "Average"
      time_grain       = "auto"
      region           = "West Europe"
      resources = [
        {
          resource_group = "rgp-alm-business-de-001"
          resource_name  = "almdevwbltn001"
        },
        {
          resource_group = "rgp-alm-business-de-001"
          resource_name  = "almdevwbltn002"
        },
      ]
    }
    threshold     = 24
    time_period   = "1m"
    frequency     = "1m"
    severity      = "critical"
    additional_labels = {
      Affected_CI = "OMN"
      CC_Contacts = "name.lastname@organization.eu"
      Category    = "infrastructure"
      TO_Contacts = "name.lastname@organization.eu"
      Subcategory = "incident"
    }
    annotation_description = "{{ index $labels \"alertname\" }} for resource name {{ index $labels \"resourceName\" }} has exceeded: {{ index $values \"B\" }} raised_by : GRAFANA"
    annotation_summary     = "{{ index $labels \"alertname\" }} for resource name {{ index $labels \"resourceName\" }} has exceeded: {{ index $values \"B\" }}"
  }
]

azure_monitor_datasource_uid = "azure-monitor-oob"
