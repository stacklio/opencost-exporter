select 
 `period`,
`resourceId`,
`product`,
`operation`,
`item_type`,
`item_description`,
`usage_type`,
`usage_unit`,
SUM(`metric_amount`) as `metric_amount`,
SUM(`metric_cost`) as `metric_cost`,
`currency`

 from (

select
    (`start` || "-" || `end`)  as `period`,
    `name` as `resourceId`,
    `name` as `product`,
    `operation` as `operation`,
    `type`  as `item_type`,
    `name` as `item_description`,
    "cpu" as `usage_type`,
    0 as `usage_unit`,
    `cpuEfficiency` as `metric_amount`,
    `cpuCost` as `metric_cost`,
    "USD" as `currency`
from `report-current.csv`
where `cpuCost` > 0

union all

select
    (`start` || "-" || `end`)  as `period`,
    `name` as `resourceId`,
    `name` as `product`,
    `operation` as `operation`,
    `type`  as `item_type`,
    `name` as `item_description`,
    "ram" as `usage_type`,
    0 as `usage_unit`,
    `ramEfficiency` as metric_amount,
    `ramCost` as metric_cost,
    "USD" as `currency`
from `report-current.csv`
where `ramCost` > 0

union all

select
    (`start` || "-" || `end`)  as `period`,
    `name` as `resourceId`,
    `name` as `product`,
    `operation` as `operation`,
    `type`  as `item_type`,
    `name` as `item_description`,
    "network" as `usage_type`,
    0 as `usage_unit`,
    0 as metric_amount,
    `networkCost` as metric_cost,
    "USD" as `currency`
from `report-current.csv`
where `networkCost` > 0

union all

select
    (`start` || "-" || `end`)  as `period`,
    `name` as `resourceId`,
    `name` as `product`,
    `operation` as `operation`,
    `type`  as `item_type`,
    `name` as `item_description`,
    "load_balancer" as `usage_type`,
    0 as `usage_unit`,
    0 as metric_amount,
    `loadBalancerCost` as metric_cost,
    "USD" as `currency`
from `report-current.csv`
where `loadBalancerCost` > 0

union all

select
    (`start` || "-" || `end`)  as `period`,
    `name` as `resourceId`,
    `name` as `product`,
    `operation` as `operation`,
    `type`  as `item_type`,
    `name` as `item_description`,
    "pv" as `usage_type`,
    0 as `usage_unit`,
    0 as metric_amount,
    `pvCost` as metric_cost,
    "USD" as `currency`
from `report-current.csv`
where `pvCost` > 0)

group by
    `period`,
    `resourceId`,
    `product`,
    `operation`,
    `item_type`,
    `usage_type`,
    `item_description`,
    
    `usage_unit`,
    `currency`
order by `period`, `product`, `operation`
