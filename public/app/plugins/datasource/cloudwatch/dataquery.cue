// Copyright 2023 Grafana Labs
//
// Licensed under the Apache License, Version 2.0 (the "License")
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package grafanaplugin

import (
	common "github.com/grafana/grafana/packages/grafana-schema/src/common"
	"github.com/grafana/grafana/pkg/plugins/pfs"
)

// This file (with its sibling .cue files) implements pfs.GrafanaPlugin
pfs.GrafanaPlugin

composableKinds: DataQuery: {
	maturity: "merged"

	lineage: {
		seqs: [
			{
				schemas: [
					{
						#MetricStat: {
							region:      string
							namespace:   string
							metricName?: string
							dimensions?: #Dimensions
							matchExact?: bool
							period?:     string
							accountId?:  string
							statistic?:  string
							// @deprecated use statistic
							statistics?: [...string]
						} @cuetsy(kind="interface")

						#Dimensions: {[string]: string | [...string]} @cuetsy(kind="type")

						#CloudWatchMetricsQuery: {
							// TODO extend common.DataQuery when the issues with redundant fields is fixed
							// common.DataQuery
							#MetricStat
							queryMode?:        #CloudWatchQueryMode
							metricQueryType?:  #MetricQueryType
							metricEditorMode?: #MetricEditorMode
							// common props
							id: string

							alias?: string
							label?: string

							// Math expression query
							expression?: string

							sqlExpression?: string
							sql?:           #SQLExpression
						} @cuetsy(kind="interface")

						#CloudWatchQueryMode: "Metrics" | "Logs" | "Annotations" @cuetsy(kind="type")
						#MetricQueryType:     0 | 1                              @cuetsy(kind="enum", memberNames="Search|Query")
						#MetricEditorMode:    0 | 1                              @cuetsy(kind="enum", memberNames="Builder|Code")
						#SQLExpression: {
							select?:           #QueryEditorFunctionExpression
							from?:             #QueryEditorPropertyExpression | #QueryEditorFunctionExpression
							where?:            #QueryEditorArrayExpression
							groupBy?:          #QueryEditorArrayExpression
							orderBy?:          #QueryEditorFunctionExpression
							orderByDirection?: string
							limit?:            int64
						} @cuetsy(kind="interface")

						#QueryEditorFunctionExpression: {
							type:  #QueryEditorExpressionType & "function"
							name?: string
							parameters?: [...#QueryEditorFunctionParameterExpression]
						} @cuetsy(kind="interface")

						#QueryEditorExpressionType: "property" | "operator" | "or" | "and" | "groupBy" | "function" | "functionParameter" @cuetsy(kind="enum")

						#QueryEditorFunctionParameterExpression: {
							type:  #QueryEditorExpressionType & "functionParameter"
							name?: string
						} @cuetsy(kind="interface")

						#QueryEditorPropertyExpression: {
							type:     #QueryEditorExpressionType & "property"
							property: #QueryEditorProperty
						} @cuetsy(kind="interface")

						#QueryEditorGroupByExpression: {
							type:     #QueryEditorExpressionType & "groupBy"
							property: #QueryEditorProperty
						} @cuetsy(kind="interface")

						#QueryEditorOperatorExpression: {
							type:     #QueryEditorExpressionType & "operator"
							property: #QueryEditorProperty
							// TODO QueryEditorOperator<QueryEditorOperatorValueType>, extend in veneer
							operator: #QueryEditorOperator
						} @cuetsy(kind="interface")

						// TODO <T extends QueryEditorOperatorValueType>, extend in veneer
						#QueryEditorOperator: {
							name?:  string
							value?: #QueryEditorOperatorType | [...#QueryEditorOperatorType]
						}

						#QueryEditorOperatorValueType: #QueryEditorOperatorType | [...#QueryEditorOperatorType] @cuetsy(kind="type")
						#QueryEditorOperatorType:      string | bool | int64                                    @cuetsy(kind="type")

						#QueryEditorProperty: {
							type:  #QueryEditorPropertyType
							name?: string
						} @cuetsy(kind="interface")

						#QueryEditorPropertyType: "string" | "test" @cuetsy(kind="enum")

						#QueryEditorArrayExpression: {
							// TODO this doesn't work
							type: (#QueryEditorExpressionType & "and") | (#QueryEditorExpressionType & "or")
							// TODO should be QueryEditorExpression[] | QueryEditorArrayExpression[], extend in veneer
							expressions: _ // TODO modify this in veneer
						} @cuetsy(kind="interface")

						#CloudWatchLogsQuery: {
							common.DataQuery
							queryMode:   #CloudWatchQueryMode
							id:          string
							region:      string
							expression?: string
							statsGroups?: [...string]
							logGroups?: [...#LogGroup]
							// deprecated, use logGroups instead
							logGroupNames?: [...string]
						} @cuetsy(kind="interface")

						#LogGroup: {
							arn:           string
							name:          string
							accountId?:    string
							accountLabel?: string
						} @cuetsy(kind="interface")

						#CloudWatchQueryMode: "Metrics" | "Logs" | "Annotations" @cuetsy(kind="type")

						#CloudWatchAnnotationQuery: {
							// TODO extend common.DataQuery when the issues with redundant fields is fixed
							//common.DataQuery
							#MetricStat
							queryMode:        #CloudWatchQueryMode
							prefixMatching?:  bool
							actionPrefix?:    string
							alarmNamePrefix?: string
						} @cuetsy(kind="interface")

						// TODO this doesn't work. Also the type is CloudWatchDefaultQuery = Omit<CloudWatchLogsQuery, 'queryMode'> & CloudWatchMetricsQuery;
						// #CloudWatchDefaultQuery: #CloudWatchLogsQuery & #CloudWatchMetricsQuery @cuetsy(kind="type")
					},
				]
			},
		]
	}
}
