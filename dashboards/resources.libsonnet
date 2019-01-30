local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'k8s-resources-cluster.json':
      local tableStyles = {
        namespace: {
          alias: 'Namespace',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell' % { prefix: $._config.grafanaPrefix, uid: std.md5('k8s-resources-namespace.json') },
        },
      };

      g.dashboard(
        'K8s / Compute Resources / Cluster',
        uid=($._config.grafanaDashboardIDs['k8s-resources-cluster.json']),
      ).addTemplate('cluster', 'node_cpu_seconds_total', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addRow(
        (g.row('Headlines') +
         {
           height: '100px',
           showTitle: false,
         })
         .addPanel(
           g.panel('CPU Utilisation') +
           g.statPanel('1 - avg(rate(node_cpu_seconds_total{mode="idle", %(clusterLabel)s="$cluster"}[1m]))' % $._config)
         )
        .addPanel(
          g.panel('CPU Requests Commitment') +
          g.statPanel('sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster"}) / sum(node:node_num_cpu:sum{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('CPU Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster"}) / sum(node:node_num_cpu:sum{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Utilisation') +
          g.statPanel('1 - sum(:node_memory_MemFreeCachedBuffers_bytes:sum{%(clusterLabel)s="$cluster"}) / sum(:node_memory_MemTotal_bytes:sum{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Requests Commitment') +
          g.statPanel('sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster"}) / sum(:node_memory_MemTotal_bytes:sum{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster"}) / sum(:node_memory_MemTotal_bytes:sum{%(clusterLabel)s="$cluster"})' % $._config)
        )
      )
      .addRow(
        g.row('CPU')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config, '{{namespace}}') +
          g.stack
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace) / sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace) / sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'CPU Usage' },
            'Value #B': { alias: 'CPU Requests' },
            'Value #C': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'CPU Limits' },
            'Value #E': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory')
        .addPanel(
          g.panel('Memory Usage (w/o cache)') +
          // Not using container_memory_usage_bytes here because that includes page cache
          g.queryPanel('sum(container_memory_rss{%(clusterLabel)s="$cluster", container_name!=""}) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('decbytes') },
        )
      )
      .addRow(
        g.row('Memory Requests')
        .addPanel(
          g.panel('Requests by Namespace') +
          g.tablePanel([
            // Not using container_memory_usage_bytes here because that includes page cache
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", container_name!=""}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", container_name!=""}) by (namespace) / sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", container_name!=""}) by (namespace) / sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'decbytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'decbytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'decbytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      ),

    'k8s-resources-namespace.json':
      local tableStyles = {
        pod: {
          alias: 'Pod',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-pod?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-pod=$__cell' % { prefix: $._config.grafanaPrefix, uid: std.md5('k8s-resources-pod.json') },
        }
      };

      g.dashboard(
        'K8s / Compute Resources / Namespace',
        uid=($._config.grafanaDashboardIDs['k8s-resources-namespace.json']),
      ).addTemplate('cluster', 'kube_pod_info', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod_name)' % $._config, '{{pod_name}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}, "pod", "$1", "pod_name", "(.*)")) by (pod)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}, "pod", "$1", "pod_name", "(.*)")) by (pod) / sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}, "pod", "$1", "pod_name", "(.*)")) by (pod) / sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'CPU Usage' },
            'Value #B': { alias: 'CPU Requests' },
            'Value #C': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'CPU Limits' },
            'Value #E': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory Usage')
        .addPanel(
          g.panel('Memory Usage') +
          g.queryPanel('sum(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", container_name!=""}) by (pod_name)' % $._config, '{{pod_name}}') +
          g.stack +
          { yaxes: g.yaxes('decbytes') },
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace",container_name!=""}, "pod", "$1", "pod_name", "(.*)")) by (pod)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace",container_name!=""}, "pod", "$1", "pod_name", "(.*)")) by (pod) / sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace",container_name!=""}, "pod", "$1", "pod_name", "(.*)")) by (pod) / sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'decbytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'decbytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'decbytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      ),

    'k8s-resources-workloads-namespace.json':
      local tableStyles = {
        workload: {
          alias: 'Workload',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-workload?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-workload=$__cell' % { prefix: $._config.grafanaPrefix, uid: std.md5('k8s-resources-workload.json') },
        },
        workload_type: {
          alias: 'Workload Type',
        },
      };

      local cpuUsageQuery = |||
        sum(
          label_replace(
            namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"},
            "pod", "$1", "pod_name", "(.*)"
          ) * on(namespace,pod) group_left(workload) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace"}
        ) by (workload)
      ||| % $._config;

      local cpuRequestsQuery = |||
        sum(
          kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}
          * on(namespace,pod) group_left(workload) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace"}
        ) by (workload)
      ||| % $._config;

      local podCountQuery = 'count(mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (workload, workload_type)' % $._config;
      local cpuLimitsQuery = std.strReplace(cpuRequestsQuery, 'requests', 'limits');

      local memUsageQuery = |||
        sum(
          label_replace(
            container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", container_name!=""},
            "pod", "$1", "pod_name", "(.*)"
          ) * on(namespace,pod) group_left(workload) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace"}
          ) by (workload)
      ||| % $._config;
      local memRequestsQuery = std.strReplace(cpuRequestsQuery, 'cpu_cores', 'memory_bytes');
      local memLimitsQuery = std.strReplace(cpuLimitsQuery, 'cpu_cores', 'memory_bytes');

      g.dashboard(
        'K8s / Compute Resources / Workloads by Namespace',
        uid=std.md5('k8s-resources-workloads-namespace.json'),
      ).addTemplate('cluster', 'kube_pod_info', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel(cpuUsageQuery, '{{workload}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            podCountQuery,
            cpuUsageQuery,
            cpuRequestsQuery,
            cpuUsageQuery + '/' + cpuRequestsQuery,
            cpuLimitsQuery,
            cpuUsageQuery + '/' + cpuLimitsQuery,
          ], tableStyles {
            'Value #A': { alias: 'Running Pods', decimals: 0 },
            'Value #B': { alias: 'CPU Usage' },
            'Value #C': { alias: 'CPU Requests' },
            'Value #D': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #E': { alias: 'CPU Limits' },
            'Value #F': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory Usage')
        .addPanel(
          g.panel('Memory Usage') +
          g.queryPanel(memUsageQuery, '{{workload}}') +
          g.stack +
          { yaxes: g.yaxes('decbytes') },
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            podCountQuery,
            memUsageQuery,
            memRequestsQuery,
            memUsageQuery + '/' + memRequestsQuery,
            memLimitsQuery,
            memUsageQuery + '/' + memLimitsQuery,
          ], tableStyles {
            'Value #A': { alias: 'Running Pods', decimals: 0 },
            'Value #B': { alias: 'Memory Usage', unit: 'decbytes' },
            'Value #C': { alias: 'Memory Requests', unit: 'decbytes' },
            'Value #D': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #E': { alias: 'Memory Limits', unit: 'decbytes' },
            'Value #F': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      ),

    'k8s-resources-workload.json':
      local tableStyles = {
        pod: {
          alias: 'Pod',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-pod?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-pod=$__cell' % { prefix: $._config.grafanaPrefix, uid: std.md5('k8s-resources-pod.json') },
        }
      };

      local cpuUsageQuery = |||
        sum(
          label_replace(
            namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"},
            "pod", "$1", "pod_name", "(.*)"
          ) * on(namespace,pod) group_left(workload) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload="$workload"}
        ) by (pod)
      ||| % $._config;

      local cpuRequestsQuery = |||
        sum(
          kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}
          * on(namespace,pod) group_left(workload) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload="$workload"}
        ) by (pod)
      ||| % $._config;

      local cpuLimitsQuery = std.strReplace(cpuRequestsQuery, 'requests', 'limits');

      local memUsageQuery = |||
        sum(
          label_replace(
            container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", container_name!=""},
            "pod", "$1", "pod_name", "(.*)"
          ) * on(namespace,pod) group_left(workload) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload="$workload"}
          ) by (pod)
      ||| % $._config;
      local memRequestsQuery = std.strReplace(cpuRequestsQuery, 'cpu_cores', 'memory_bytes');
      local memLimitsQuery = std.strReplace(cpuLimitsQuery, 'cpu_cores', 'memory_bytes');

      g.dashboard(
        'K8s / Compute Resources / Workload',
        uid=std.md5('k8s-resources-workload.json'),
      ).addTemplate('cluster', 'kube_pod_info', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addTemplate('workload', 'mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace"}' % $._config, 'workload')
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel(cpuUsageQuery, '{{pod}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            cpuUsageQuery,
            cpuRequestsQuery,
            cpuUsageQuery + '/' + cpuRequestsQuery,
            cpuLimitsQuery,
            cpuUsageQuery + '/' + cpuLimitsQuery,
          ], tableStyles {
            'Value #A': { alias: 'CPU Usage' },
            'Value #B': { alias: 'CPU Requests' },
            'Value #C': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'CPU Limits' },
            'Value #E': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory Usage')
        .addPanel(
          g.panel('Memory Usage') +
          g.queryPanel(memUsageQuery, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('decbytes') },
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            memUsageQuery,
            memRequestsQuery,
            memUsageQuery + '/' + memRequestsQuery,
            memLimitsQuery,
            memUsageQuery + '/' + memLimitsQuery,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'decbytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'decbytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'decbytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      ),

    'k8s-resources-pod.json':
      local tableStyles = {
        container: {
          alias: 'Container',
        },
      };

      g.dashboard(
        'K8s / Compute Resources / Pod',
        uid=($._config.grafanaDashboardIDs['k8s-resources-pod.json']),
      ).addTemplate('cluster', 'kube_pod_info', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addTemplate('pod', 'kube_pod_info{%(clusterLabel)s="$cluster", namespace="$namespace"}' % $._config, 'pod')
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{namespace="$namespace", pod_name="$pod", container_name!="POD", %(clusterLabel)s="$cluster"}) by (container_name)' % $._config, '{{container_name}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name!="POD"}, "container", "$1", "container_name", "(.*)")) by (container)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod"}, "container", "$1", "container_name", "(.*)")) by (container) / sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod"}, "container", "$1", "container_name", "(.*)")) by (container) / sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'CPU Usage' },
            'Value #B': { alias: 'CPU Requests' },
            'Value #C': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'CPU Limits' },
            'Value #E': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory Usage')
        .addPanel(
          g.panel('Memory Usage') +
          g.queryPanel('sum(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name!="POD", container_name!=""}) by (container_name)' % $._config, '{{container_name}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name!="POD", container_name!=""}, "container", "$1", "container_name", "(.*)")) by (container)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod"}, "container", "$1", "container_name", "(.*)")) by (container) / sum(kube_pod_container_resource_requests_memory_bytes{namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container)' % $._config,
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name!=""}, "container", "$1", "container_name", "(.*)")) by (container) / sum(kube_pod_container_resource_limits_memory_bytes{namespace="$namespace", pod="$pod"}) by (container)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'decbytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'decbytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'decbytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      ),
  }
  + if $._config.showMultiCluster then {
    'k8s-resources-multicluster.json':
      local tableStyles = {
        [$._config.clusterLabel]: {
          alias: 'Cluster',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-cluster?var-datasource=$datasource&var-cluster=$__cell' % { prefix: $._config.grafanaPrefix, uid: std.md5('k8s-resources-cluster.json') },
        },
      };

      g.dashboard(
        'K8s / Compute Resources /  Multi-Cluster',
        uid=($._config.grafanaDashboardIDs['k8s-resources-multicluster.json']),
      ).addRow(
        (g.row('Headlines') +
         {
           height: '100px',
           showTitle: false,
         })
         .addPanel(
           g.panel('CPU Utilisation') +
           g.statPanel('1 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m]))' % $._config)
         )
        .addPanel(
          g.panel('CPU Requests Commitment') +
          g.statPanel('sum(kube_pod_container_resource_requests_cpu_cores) / sum(node:node_num_cpu:sum)' % $._config)
        )
        .addPanel(
          g.panel('CPU Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_cpu_cores) / sum(node:node_num_cpu:sum)' % $._config)
        )
        .addPanel(
          g.panel('Memory Utilisation') +
          g.statPanel('1 - sum(:node_memory_MemFreeCachedBuffers_bytes:sum) / sum(:node_memory_MemTotal_bytes:sum)' % $._config)
        )
        .addPanel(
          g.panel('Memory Requests Commitment') +
          g.statPanel('sum(kube_pod_container_resource_requests_memory_bytes) / sum(:node_memory_MemTotal_bytes:sum)' % $._config)
        )
        .addPanel(
          g.panel('Memory Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_memory_bytes) / sum(:node_memory_MemTotal_bytes:sum)' % $._config)
        )
      )
      .addRow(
        g.row('CPU')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s)' % $._config, '{{%(clusterLabel)s}}' % $._config)
          + {fill: 0, linewidth: 2},
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores) by (%(clusterLabel)s)' % $._config,
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s) / sum(kube_pod_container_resource_requests_cpu_cores) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores) by (%(clusterLabel)s)' % $._config,
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s) / sum(kube_pod_container_resource_limits_cpu_cores) by (%(clusterLabel)s)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'CPU Usage' },
            'Value #B': { alias: 'CPU Requests' },
            'Value #C': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'CPU Limits' },
            'Value #E': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory')
        .addPanel(
          g.panel('Memory Usage (w/o cache)') +
          // Not using container_memory_usage_bytes here because that includes page cache
          g.queryPanel('sum(container_memory_rss{container_name!=""}) by (%(clusterLabel)s)' % $._config, '{{%(clusterLabel)s}}' % $._config) +
          { fill: 0, linewidth: 2, yaxes: g.yaxes('decbytes') },
        )
      )
      .addRow(
        g.row('Memory Requests')
        .addPanel(
          g.panel('Requests by Namespace') +
          g.tablePanel([
            // Not using container_memory_usage_bytes here because that includes page cache
            'sum(container_memory_rss{container_name!=""}) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes) by (%(clusterLabel)s)' % $._config,
            'sum(container_memory_rss{container_name!=""}) by (%(clusterLabel)s) / sum(kube_pod_container_resource_requests_memory_bytes) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes) by (%(clusterLabel)s)' % $._config,
            'sum(container_memory_rss{container_name!=""}) by (%(clusterLabel)s) / sum(kube_pod_container_resource_limits_memory_bytes) by (%(clusterLabel)s)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'decbytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'decbytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'decbytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      ),
  } else {},
}
