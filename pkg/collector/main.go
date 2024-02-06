package collector

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/st8ed/opencost-exporter/pkg/fetcher"
	"github.com/st8ed/opencost-exporter/pkg/state"

	"github.com/go-kit/log"

	"time"

	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func Prefetch(
	state *state.State,
	config *state.Config,
	client *s3.Client,
	registry *prometheus.Registry,
	periods []state.BillingPeriod,
	logger log.Logger,
) error {
	for i, period := range periods {
		isLast := (i == len(periods)-1)
		_, isCached := state.ReportLastModified[string(period)]

		if !isCached || isLast {
			if _, err := UpdateReport(state, config, client, &period, logger); err != nil {
				return err
			}
		}
	}

	return nil
}

func UpdateReport(
	state *state.State, config *state.Config,
	client *s3.Client,
	period *state.BillingPeriod,
	logger log.Logger,
) (updated bool, err error) {
	lastModified, ok := state.ReportLastModified[string(*period)]

	if !ok || lastModified.IsZero() {
		lastModified = time.Now()
	}

	if err := fetcher.FetchReport(config, client, period, logger); err != nil {
		return false, err
	}

	state.ReportLastModified[string(*period)] = lastModified

	return true, nil
}
