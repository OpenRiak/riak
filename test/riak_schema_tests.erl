%% -------------------------------------------------------------------
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(riak_schema_tests).

-include_lib("eunit/include/eunit.hrl").
-compile([export_all, nowarn_export_all]).

%% basic schema test will check to make sure that all defaults from the schema
%% make it into the generated app.config
base_riak_schema_test() ->
    Config =
        cuttlefish_unit:generate_templated_config(
            ["priv/riak.schema"],
            [],
            context(),
            predefined_schema()
        ),
    cuttlefish_unit:assert_config(
        Config,
        "kernel.logger_level",
        info
    ),
    cuttlefish_unit:assert_config(
        Config,
        "kernel.logger",
        expected_default_handler_config()
    ),
    cuttlefish_unit:assert_config(
        Config,
        "vm_args",
        expected_default_vmargs()
    ).

advanced_logger_schema_test() ->
    Config =
        [
            {
                ["logger", "default_filters"],
                "crash|error|progress|sasl|backend|background"
            },
            {
                ["logger", "additional_handlers"],
                "crash|error|report|backend|background"
            }
        ],
    GenConfig =
        cuttlefish_unit:generate_templated_config(
            ["priv/riak.schema"],
            Config,
            context(),
            predefined_schema()
        ),
    {kernel, LoggingConfig} = lists:keyfind(kernel, 1, GenConfig),
    {logger, HandlerConfig} = lists:keyfind(logger, 1, LoggingConfig),
    ?assertMatch(6, length(HandlerConfig)).

bad_filter_schema_test() ->
    Config =
        [
            {
                ["logger", "default_filters"],
                "crash|hesawrongun|progress|sasl|backend|background"
            },
            {
                ["logger", "additional_handlers"],
                "crash|error|report|backend|background"
            }
        ],
    ErrorConfig =
        cuttlefish_unit:generate_templated_config(
            ["priv/riak.schema"],
            Config,
            context(),
            predefined_schema()
        ),
    {error, validation, {errorlist, ErrorList}} = ErrorConfig,
    [{error, {validation, {ValTest, ValReport}}}] = ErrorList,
    ?assertMatch("logger.default_filters", ValTest),
    ?assertMatch(
        "must be a '|' list containing only "
        "crash, error, progress, report, sasl, backend or background",
        ValReport
    ).

bad_handler_schema_test() ->
    Config =
        [
            {
                ["logger", "default_filters"],
                "crash|error|progress|sasl|backend|background"
            },
            {
                ["logger", "additional_handlers"],
                "crash|hesawrongun|report|backend|background"
            }
        ],
    ErrorConfig =
        cuttlefish_unit:generate_templated_config(
            ["priv/riak.schema"],
            Config,
            context(),
            predefined_schema()
        ),
    {error, validation, {errorlist, ErrorList}} = ErrorConfig,
    [{error, {validation, {ValTest, ValReport}}}] = ErrorList,
    ?assertMatch("logger.additional_handlers", ValTest),
    ?assertMatch(
        "must be a '|' list containing only "
        "crash, error, report, backend, background or json",
        ValReport
    ).

expected_default_vmargs() ->
    [
        {'+A',64},
        {'+scl',"false"},
        {'+sfwi',500},
        {'+zdbbl',"32MB"},
        {'-setcookie',"riak"},
        {'+B',"i"}
    ].

expected_default_handler_config() ->
    [
        {
            handler,
            default,
            logger_std_h,
            #{
                config => 
                    #{
                        file => "./log/console.log",
                        file_check => 100,
                        max_no_bytes => 1048576,
                        max_no_files => 10
                    },
                level => all,
                filter_default => log,
                filters => [],
                formatter => 
                    {
                        logger_formatter,
                        #{
                            single_line => true,
                            legacy_header => false,
                            template => log_template(),
                            time_designator => $\s
                        }
                    }
                }
        }
    ].

log_template() ->
    [time," [",level,"] ",pid,"@",mfa,":",line," ",msg,"\n"].

context() ->
    [
        {logger_level , "info"}
    ].

predefined_schema() ->
    Mapping =
        cuttlefish_mapping:parse(
            {
                mapping,
                "platform_log_dir",
                "riak_core.platform_log_dir",
                [
                    {default, "./log"},
                    {datatype, directory}
                ]
            }
        ),
    {[], [Mapping], []}.