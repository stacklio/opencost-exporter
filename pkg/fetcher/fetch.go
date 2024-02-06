package fetcher

import (
	"path"

	"github.com/st8ed/opencost-exporter/pkg/state"

	"context"
	"errors"
	"fmt"
	"path/filepath"
	"sort"
	"strings"

	"github.com/go-kit/log"
	"github.com/go-kit/log/level"

	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

type ReportManifest struct {
	AssemblyId    string `json:"assemblyId"`
	Compression   string `json:"compression"`
	ContentType   string `json:"contentType"`
	BillingPeriod struct {
		Start string `json:"start"`
		End   string `json:"end"`
	} `json:"billingPeriod"`
	Bucket     string   `json:"bucket"`
	ReportKeys []string `json:"reportKeys"`
}

type SortRecentFirst []state.BillingPeriod

func (a SortRecentFirst) Len() int           { return len(a) }
func (a SortRecentFirst) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a SortRecentFirst) Less(i, j int) bool { return a[i] < a[j] }

func GetBillingPeriods(config *state.Config, client *s3.Client) ([]state.BillingPeriod, error) {
	params := &s3.ListObjectsV2Input{
		Bucket:    aws.String(config.BucketName),
		Prefix:    aws.String(""),
		Delimiter: aws.String(""),
	}

	periods := make([]state.BillingPeriod, 0)
	p := s3.NewListObjectsV2Paginator(client, params)

	for p.HasMorePages() {
		page, err := p.NextPage(context.TODO())
		if err != nil {
			return nil, err
		}

		for _, obj := range page.Contents {
			if path.Ext(*obj.Key) == ".csv" {
				period, err := state.ParseBillingPeriod(
					strings.TrimSuffix(*obj.Key, ".csv"),
				)

				if err != nil {
					return nil, err
				}

				periods = append(periods, *period)
			}
		}
	}

	sort.Sort(SortRecentFirst(periods))

	if len(periods) > 3 {
		return periods[len(periods)-3:], nil
	} else {
		return periods, nil
	}
}

/*
	func GetReportManifest(config *state.Config, client *s3.Client, period *state.BillingPeriod, lastModified *time.Time) (*ReportManifest, error) {
		params := &s3.GetObjectInput{
			Bucket: aws.String(config.BucketName),
			Key: aws.String(fmt.Sprintf(
				"/%s/%s/%s-Manifest.json",
				config.ReportName, string(*period), config.ReportName,
			)),
			IfModifiedSince: aws.Time(*lastModified),
		}

		obj, err := client.GetObject(context.TODO(), params)
		if err != nil {
			var ae smithy.APIError

			if !errors.As(err, &ae) {
				return nil, err
			}

			if ae.ErrorCode() == "NotModified" {
				return nil, nil
			} else {
				return nil, err
			}
		}
		defer obj.Body.Close()

		*lastModified = *obj.LastModified
		manifest := &ReportManifest{}

		decoder := json.NewDecoder(obj.Body)
		if err := decoder.Decode(&manifest); err != nil {
			return nil, err
		}

		if manifest.ContentType != "text/csv" {
			return nil, fmt.Errorf("report manifest contains unknown content type: %s", manifest.ContentType)
		}

		if manifest.Bucket != config.BucketName {
			return nil, fmt.Errorf("report manifest contains unexpected bucket name: %s", manifest.Bucket)
		}

		if len(manifest.ReportKeys) == 0 {
			return nil, fmt.Errorf("report manifest contains no report keys")
		}

		return manifest, nil
	}
*/
func FetchReport(config *state.Config, client *s3.Client, period *state.BillingPeriod, logger log.Logger) error {
	ReportFile := fmt.Sprintf("%s.csv", string(*period))

	localReportFile := filepath.Join(
		config.RepositoryPath, "data",
		ReportFile,
	)

	if _, err := os.Stat(localReportFile); !errors.Is(err, os.ErrNotExist) {
		level.Warn(logger).Log("msg", "Report file already exists, skipping download", "file", localReportFile)
		return nil
	}

	level.Info(logger).Log("msg", "Fetching report", "file", ReportFile)

	downloadFromS3(client, config.BucketName, ReportFile, localReportFile)

	return nil
}

func downloadFromS3(client *s3.Client, bucketName, key string, save_path string) ([]byte, error) {

	resp, err := client.GetObject(context.TODO(), &s3.GetObjectInput{
		Bucket: aws.String(bucketName),
		Key:    aws.String(key),
	})

	if err != nil {
		return nil, fmt.Errorf("failed to download %s to S3: %v", key, err)
	}
	defer resp.Body.Close()

	buf := make([]byte, 1024)
	var data []byte
	for {
		n, err := resp.Body.Read(buf)
		if n > 0 {
			data = append(data, buf[:n]...)
		}
		if err != nil {
			break
		}
	}
	os.WriteFile(save_path, data, os.ModePerm)
	return data, nil
}
