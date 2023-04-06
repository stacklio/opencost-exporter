select
    (`bill/BillingPeriodStartDate` || "-" || `bill/BillingPeriodEndDate`)  as `period`,

    `lineItem/ResourceId` as `resourceId`,
    `product/ProductName` as `product`,
    `lineItem/Operation` as `operation`,
    `lineItem/LineItemType` as `item_type`,
    `lineItem/LineItemDescription` as `item_description`,

    `lineItem/UsageType` as `usage_type`,
    `pricing/unit` as `usage_unit`,
    SUM(`lineItem/UsageAmount`) as metric_amount,

    SUM(`lineItem/UnblendedCost`) as metric_cost,
    `lineItem/CurrencyCode` as `currency`
from `report-current.csv`
where `lineItem/UnblendedCost` > 0
group by
    `lineItem/ResourceId`,
    `bill/BillingPeriodStartDate`,
    `bill/BillingPeriodEndDate`,
    `product/ProductName`,
    `lineItem/Operation`,
    `lineItem/LineItemType`,
    `lineItem/LineItemDescription`,
    
    `lineItem/UsageType`,
    `pricing/unit`,
    `lineItem/CurrencyCode`
order by `period`, `product`, `operation`
