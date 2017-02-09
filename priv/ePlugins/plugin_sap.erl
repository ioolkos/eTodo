%%%-------------------------------------------------------------------
%%% @author Mikael Bylund <mikael.bylund@gmail.com>
%%% @copyright (C) 2016, Mikael Bylund
%%% @doc
%%%
%%% @end
%%% Created : 09 February 2016 by Mikael Bylund <mikael.bylund@gmail.com>
%%%-------------------------------------------------------------------

-module(plugin_sap).

-export([getName/0, getDesc/0, getMenu/2, init/1, terminate/2]).

-export([eGetStatusUpdate/5,
         eTimerStarted/7,
         eTimerStopped/3,
         eTimerEnded/4,
         eReceivedMsg/5,
         eReceivedSysMsg/3,
         eReceivedAlarmMsg/3,
         eLoggedInMsg/3,
         eLoggedOutMsg/3,
         eSetStatusUpdate/5,
         eSetWorkLogDate/4,
         eMenuEvent/6]).

getName() -> "SAP".

getDesc() -> "SAP time reporting integration.".

-include_lib("wx/include/wx.hrl").
-include_lib("eTodo/include/eTodo.hrl").

-record(state, {frame, conf, file, date = date()}).

%%--------------------------------------------------------------------
%% @doc
%% initalize plugin.
%% @spec init() -> State.
%% @end
%%--------------------------------------------------------------------
init([WX, Frame]) ->
    wx:set_env(WX),
    {ok, Dir}  = application:get_env(mnesia, dir),
    ConfigFile = filename:join(Dir, "plugin_sap.dat"),
    Config     = case file:consult(ConfigFile) of
                     {ok, [Cfg]} when is_map(Cfg) ->
                         Cfg;
                     _ ->
                         #{}
                 end,
    #state{frame = Frame, conf = Config, file = ConfigFile}.

%%--------------------------------------------------------------------
%% @doc
%% Free internal data for plugin.
%% @spec init() -> State.
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) -> ok.

%%--------------------------------------------------------------------
%% @doc
%% Return key value list of right menu options.
%% Menu option should be a unique integer bigger than 1300.
%% @spec getMenu(ETodo, State) -> {ok, [{menuOption, menuText}, ...], NewState}
%% @end
%%--------------------------------------------------------------------
getMenu(undefined, State) ->
    {ok, [{1600, "Create project"},
          {1601, "Delete project"},
          {1604, "Project week to clipboard"}], State};
getMenu(_ETodo, State) ->
    {ok, [{1600, "Create project"},
          {1601, "Delete project"},
          {1602, "Assign project"},
          {1603, "Remove from project"},
          {1604, "Project week to clipboard"}], State}.

%%--------------------------------------------------------------------
%% @doc
%% Called every 15 seconds to check if someone changes status
%% outside eTodo.
%% Status can be "Available" | "Away" | "Busy" | "Offline"
%% @spec eSetStatusUpdate(Dir, User, Status, StatusMsg, State) ->
%%       {ok, Status, StatusMsg, NewState}
%% @end
%%--------------------------------------------------------------------
eGetStatusUpdate(_Dir, _User, Status, StatusMsg, State) ->
    {ok, Status, StatusMsg, State}.

%%--------------------------------------------------------------------
%% @doc
%% The user start timer
%%
%% @spec eTimerStarted(EScriptDir, User, Text, Hours, Min, Sec, State) ->
%%                     NewState
%% @end
%%--------------------------------------------------------------------
eTimerStarted(_Dir, _User, _Text, _Hours, _Min, _Sec, State) ->
    State.

%%--------------------------------------------------------------------
%% @doc
%% The user stopped timer
%%
%% @spec eTimerStopped(EScriptDir, User, State) -> NewState
%% @end
%%--------------------------------------------------------------------
eTimerStopped(_EScriptDir, _User, State) ->
    State.

%%--------------------------------------------------------------------
%% @doc
%% Timer ended
%%
%% @spec eTimerEnded(EScriptDir, User, Text, State) -> NewState
%% @end
%%--------------------------------------------------------------------
eTimerEnded(_EScriptDir, _User, _Text, State) ->
    State.

%%--------------------------------------------------------------------
%% @doc
%% The user receives a system message.
%%
%% @spec eReceivedMsg(Dir, User, Users, Text, State) -> NewState
%% @end
%%--------------------------------------------------------------------
eReceivedMsg(_EScriptDir, _User, _Users, _Text, State) ->
    State.

%%--------------------------------------------------------------------
%% @doc
%% The user receives an alarm.
%%
%% @spec eReceivedAlarmMsg(Dir, Text, State) -> NewState
%% @end
%%--------------------------------------------------------------------
eReceivedSysMsg(_Dir, _Text, State) ->
    State.

%%--------------------------------------------------------------------
%% @doc
%% The user receives an alarm.
%%
%% @spec eReceivedAlarmMsg(Dir, Text, State) -> NewState
%% @end
%%--------------------------------------------------------------------
eReceivedAlarmMsg(_Dir, _Text, State) ->
    State.

%%--------------------------------------------------------------------
%% @doc
%% Called when a peer connected to the users circle logs in.
%%
%% @spec eLoggedInMsg(Dir, User, State) -> NewState
%% @end
%%--------------------------------------------------------------------
eLoggedInMsg(_Dir, _User, State) ->
    State.

%%--------------------------------------------------------------------
%% @doc
%% Called when a peer connected to the users circle logs out.
%%
%% @spec eLoggedOutMsg(Dir, User, State) -> NewState
%% @end
%%--------------------------------------------------------------------
eLoggedOutMsg(_Dir, _User, State) ->
    State.

%%--------------------------------------------------------------------
%% @doc
%% Called every time the user changes his/her status in eTodo
%% Status can be "Available" | "Away" | "Busy" | "Offline"
%% @spec eSetStatusUpdate(Dir, User, Status, StatusMsg, State) ->
%%       NewState
%% @end
%%--------------------------------------------------------------------
eSetStatusUpdate(_Dir, _User, _Status, _StatusMsg, State) ->
    State.

%%--------------------------------------------------------------------
%% @doc
%% Called every time the user changes work log date
%% @spec eSetWorkLogDate(Dir, User, Date, State) ->
%%       NewState
%% @end
%%--------------------------------------------------------------------
eSetWorkLogDate(_Dir, _User, Date, State) ->
    State#state{date = Date}.

%%--------------------------------------------------------------------
%% @doc
%% Called for right click menu
%%
%% @spec eMenuEvent(EScriptDir, User, MenuOption, ETodo, MenuText, State) ->
%%       NewState
%% @end
%%--------------------------------------------------------------------
eMenuEvent(_EScriptDir, _User, 1600, _ETodo, _MenuText, State) ->
    doCreateProject(State);
eMenuEvent(_EScriptDir, _User, 1601, _ETodo, _MenuText, State) ->
    doDeleteProject(State);
eMenuEvent(_EScriptDir, _User, 1602, ETodo, _MenuText, State) ->
    doAssignProject(ETodo, State);
eMenuEvent(_EScriptDir, _User, 1603, ETodo, _MenuText, State) ->
    doRemoveFromProject(ETodo, State);
eMenuEvent(_EScriptDir, User, 1604, _ETodo, _MenuText, State) ->
    doCopyWeekToClipboard(User, State);
eMenuEvent(_EScriptDir, _User, _MenuOption, _ETodo, _MenuText, State) ->
    State.

doCreateProject(State = #state{frame = Frame, conf = Config, file = CFile}) ->
    ProjDlg = wxTextEntryDialog:new(Frame, "Enter WBS"),
    Config2 = case wxTextEntryDialog:showModal(ProjDlg) of
                  ?wxID_OK ->
                      ProjText = wxTextEntryDialog:getValue(ProjDlg),
                      Config#{ProjText => []};
                  _ ->
                      Config
              end,
    wxTextEntryDialog:destroy(ProjDlg),
    file:write_file(CFile, io_lib:format("~tp.~n", [Config2])),
    State#state{conf = Config2}.

doDeleteProject(State = #state{frame = Frame, conf = Config, file = CFile}) ->
    ProjDlg = wxSingleChoiceDialog:new(Frame, "Choose WBS to delete",
                                       "Delete WBS", maps:keys(Config)),
    wxSingleChoiceDialog:setSize(ProjDlg, {300, 400}),
    Config2 = case wxSingleChoiceDialog:showModal(ProjDlg) of
                  ?wxID_OK ->
                      ProjText = wxSingleChoiceDialog:getStringSelection(ProjDlg),
                      maps:remove(ProjText, Config);
                  _ ->
                      Config
              end,
    wxSingleChoiceDialog:destroy(ProjDlg),
    file:write_file(CFile, io_lib:format("~tp.~n", [Config2])),
    State#state{conf = Config2}.

doAssignProject(ETodo, State = #state{frame = Frame, conf = Config, file = CFile}) ->
    ProjDlg = wxSingleChoiceDialog:new(Frame, "Choose WBS to assign",
                                       "Assign WBS", maps:keys(Config)),
    wxSingleChoiceDialog:setSize(ProjDlg, {300, 400}),
    Config2 = case wxSingleChoiceDialog:showModal(ProjDlg) of
                  ?wxID_OK ->
                      Uid       = ETodo#etodo.uid,
                      ProjText  = wxSingleChoiceDialog:getStringSelection(ProjDlg),
                      Projects  = maps:get(ProjText, Config),
                      Projects2 = [Uid|lists:delete(Uid, Projects)],
                      Config#{ProjText := Projects2};
                  _ ->
                      Config
              end,
    wxSingleChoiceDialog:destroy(ProjDlg),
    file:write_file(CFile, io_lib:format("~tp.~n", [Config2])),
    State#state{conf = Config2}.

doRemoveFromProject(ETodo, State = #state{frame = Frame, conf = Config, file = CFile}) ->
    Choices = filterProjects(Config, ETodo#etodo.uid),
    ProjDlg = wxSingleChoiceDialog:new(Frame, "Remove WBS from task",
                                       "Remove WBS", Choices),
    wxSingleChoiceDialog:setSize(ProjDlg, {300, 400}),
    Config2 = case wxSingleChoiceDialog:showModal(ProjDlg) of
                  ?wxID_OK ->
                      Uid       = ETodo#etodo.uid,
                      ProjText  = wxSingleChoiceDialog:getStringSelection(ProjDlg),
                      Projects  = maps:get(ProjText, Config),
                      Projects2 = lists:delete(Uid, Projects),
                      Config#{ProjText := Projects2};
                  _ ->
                      Config
              end,
    wxSingleChoiceDialog:destroy(ProjDlg),
    file:write_file(CFile, io_lib:format("~tp.~n", [Config2])),
    State#state{conf = Config2}.

doCopyWeekToClipboard(User, State = #state{frame = Frame,
                                           conf  = Config,
                                           date  = Date}) ->
    ProjDlg = wxSingleChoiceDialog:new(Frame,
                                       "Choose WBS to copy to clipboard",
                                       "Copy WBS", maps:keys(Config)),
    wxSingleChoiceDialog:setSize(ProjDlg, {300, 400}),
    case wxSingleChoiceDialog:showModal(ProjDlg) of
        ?wxID_OK ->
            ProjText = wxSingleChoiceDialog:getStringSelection(ProjDlg),
            Tasks    = maps:get(ProjText, Config),
            {D1, D2, D3, D4, D5} = calcWorkLog(User, Tasks, Date),
            CopyStr = lists:flatten(io_lib:format("~p\t\t\t\t~p\t\t\t\t"
                                                  "~p\t\t\t\t~p\t\t\t\t~p",
                                                  [D1, D2, D3, D4, D5])),
            eGuiFunctions:toClipboard(replaceComma(CopyStr));
        _ ->
            ok
    end,
    wxSingleChoiceDialog:destroy(ProjDlg),
    State.

filterProjects(Config, Uid) ->
    Projects = maps:keys(Config),
    filterProjects(Projects, Config, Uid, []).

filterProjects([], _, _, Acc) ->
    lists:reverse(Acc);
filterProjects([Project|Rest], Config, Uid, Acc) ->
    case lists:member(Uid, maps:get(Project, Config)) of
        true ->
            filterProjects(Rest, Config, Uid, [Project|Acc]);
        false ->
            filterProjects(Rest, Config, Uid, Acc)
    end.

incDate(Date, Inc) ->
    Days = calendar:date_to_gregorian_days(Date),
    calendar:gregorian_days_to_date(Days + Inc).

calcWorkLog(User, Tasks, Date) ->
    calcWorkLog(User, Tasks, Date, {0, 0, 0, 0, 0}).

calcWorkLog(_User, [], _Date, Acc) ->
    Acc;
calcWorkLog(User, [Uid|Rest], Date, {D1, D2, D3, D4, D5}) ->
    {_, H1, M1} = eTodoDB:getLoggedWork(User, Uid, Date),
    {_, H2, M2} = eTodoDB:getLoggedWork(User, Uid, incDate(Date, 1)),
    {_, H3, M3} = eTodoDB:getLoggedWork(User, Uid, incDate(Date, 2)),
    {_, H4, M4} = eTodoDB:getLoggedWork(User, Uid, incDate(Date, 3)),
    {_, H5, M5} = eTodoDB:getLoggedWork(User, Uid, incDate(Date, 4)),

    ND1 = addMinutes(D1 + H1, M1),
    ND2 = addMinutes(D2 + H2, M2),
    ND3 = addMinutes(D3 + H3, M3),
    ND4 = addMinutes(D4 + H4, M4),
    ND5 = addMinutes(D5 + H5, M5),

    calcWorkLog(User, Rest, Date, {ND1, ND2, ND3, ND4, ND5}).

addMinutes(Hours, Min) ->
    case Min rem 60 of
        0 ->
            Hours + Min div 60;
        _ ->
            Hours + Min/60
    end.

replaceComma(String) ->
    replaceComma(String, []).

replaceComma([], Acc) ->
    lists:reverse(Acc);
replaceComma([$.|Rest], Acc) ->
    replaceComma(Rest, [$,|Acc]);
replaceComma([Char|Rest], Acc) ->
    replaceComma(Rest, [Char|Acc]).