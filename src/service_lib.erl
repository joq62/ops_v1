%%% -------------------------------------------------------------------
%%% @author  : Joq Erlang
%%% @doc: : 
%%% Created :
%%% Node end point  
%%% Creates and deletes Pods
%%% 
%%% API-kube: Interface 
%%% Pod consits beams from all services, app and app and sup erl.
%%% The setup of envs is
%%% -------------------------------------------------------------------
-module(service_lib).   
  
-export([
	 git_load/4,
	 git_load/5,
	 load/5,
	 start/5,
	 stop/5,
	 unload/5,
	 is_running/5,
	 is_loaded/5
	]).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
git_load(HostName,ClusterName,PodName,Appl,ClusterSpec)->
    {ok,PodInfo}=pod_data:pod_info_by_name(HostName,ClusterName,PodName,ClusterSpec),
    PodNode=pod_data:pod(node,PodInfo),
    PodDir=pod_data:pod(dir,PodInfo),
    {ok,ClusterCookie}=cluster_data:cluster_spec(cookie,HostName,ClusterName,ClusterSpec),
    Result=git_load(PodNode,ClusterCookie,Appl,PodDir),
    Result.
	

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------

git_load(PodNode,ClusterCookie,Appl,PodDir)->
    GitPath=config:application_gitpath(Appl),
    App=list_to_atom(Appl), 
    {ok,Root}= dist_lib:cmd(PodNode,ClusterCookie,file,get_cwd,[],1000),  
    ApplDir=filename:join([Root,PodDir,Appl]),
    dist_lib:cmd(PodNode,ClusterCookie,os,cmd,["rm -rf "++ApplDir],1000),
    timer:sleep(1000),
    ok=dist_lib:cmd(PodNode,ClusterCookie,file,make_dir,[ApplDir],1000),
    TempDir=filename:join(Root,"temp.dir"),
    dist_lib:cmd(PodNode,ClusterCookie,os,cmd,["rm -rf "++TempDir],1000),
    timer:sleep(1000),
    ok=dist_lib:cmd(PodNode,ClusterCookie,file,make_dir,[TempDir],1000),
    _Clonres= dist_lib:cmd(PodNode,ClusterCookie,os,cmd,["git clone "++GitPath++" "++TempDir],5000),
    timer:sleep(1000),
  %  io:format("Clonres ~p~n",[Clonres]),

    _MvRes= dist_lib:cmd(PodNode,ClusterCookie,os,cmd,["mv  "++TempDir++"/*"++" "++ApplDir],5000),
    %io:format("MvRes ~p~n",[MvRes]),
 %   rpc:cast(node(),nodelog_server,log,[info,?MODULE_STRING,?LINE,
%				     {mv_result,MvRes}]),
    _RmRes= dist_lib:cmd(PodNode,ClusterCookie,os,cmd,["rm -r  "++TempDir],5000),
    timer:sleep(1000),
    %io:format("RmRes ~p~n",[RmRes]),
    %rpc:cast(node(),nodelog_server,log,[info,?MODULE_STRING,?LINE,
%				     {rm_result,RmRes}]),
    Ebin=filename:join(ApplDir,"ebin"),
    Result=case  dist_lib:cmd(PodNode,ClusterCookie,filelib,is_dir,[Ebin],5000) of
	      true->
		  case  dist_lib:cmd(PodNode,ClusterCookie,code,add_patha,[Ebin],5000) of
		      true->
			  dist_lib:cmd(PodNode,ClusterCookie,application,load,[App],5000);
		      {badrpc,Reason} ->
			  {error,[badrpc,?MODULE,?FUNCTION_NAME,?LINE,Reason]};
		      Err ->
			  {error,[?MODULE,?FUNCTION_NAME,?LINE,Err]}
		  end;
	      false ->
		  {error,[ebin_dir_not_created,?MODULE,?FUNCTION_NAME,?LINE,PodNode]};
	      {badrpc,Reason} ->

		  {error,[?MODULE,?FUNCTION_NAME,?LINE,badrpc,Reason]}
	  end,
    Result.

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
load(PodNode,ClusterCookie,Appl,SourceDir,ApplDir)->
    App=list_to_atom(Appl),
    Result= case dist_lib:mkdir(PodNode,ClusterCookie,ApplDir) of
		{error,Reason}->
		    {error,Reason};
		ok->
		    EbinApplDir=filename:join(ApplDir,"ebin"),
		    case dist_lib:mkdir(PodNode,ClusterCookie,EbinApplDir) of
			{error,Reason}->
			    {error,Reason};
			ok->
			    case file:list_dir(SourceDir) of
				{error,Reason}->
				    {error,Reason};
				{ok,EbinFiles}->
				    [dist_lib:cp_file(PodNode,ClusterCookie,SourceDir,SourcFileName,EbinApplDir)||SourcFileName<-EbinFiles], 
				    case dist_lib:cmd(PodNode,ClusterCookie,code,add_patha,[EbinApplDir],5000) of
					{error,Reason}->
					    {error,Reason};
					true->
					    dist_lib:cmd(PodNode,ClusterCookie,application,load,[App],5000)
				    end
			    end
		    end
	    end,
    Result.

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
start(HostName,ClusterName,PodName,Appl,ClusterSpec)->
    {ok,PodInfo}=pod_data:pod_info_by_name(HostName,ClusterName,PodName,ClusterSpec),
    PodNode=pod_data:pod(node,PodInfo),
    {ok,ClusterCookie}=cluster_data:cluster_spec(cookie,HostName,ClusterName,ClusterSpec),
    Result=start(PodNode,ClusterCookie,Appl),
  %  io:format("Result ~p~n",[{?MODULE,?FUNCTION_NAME,?LINE,Result}]),
    Result.



start(PodNode,ClusterCookie,Appl)->
    App=list_to_atom(Appl),
    dist_lib:cmd(PodNode,ClusterCookie,application,start,[App],5000).

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
stop(HostName,ClusterName,PodName,Appl,ClusterSpec)->
    {ok,PodInfo}=pod_data:pod_info_by_name(HostName,ClusterName,PodName,ClusterSpec),
    PodNode=pod_data:pod(node,PodInfo),
    {ok,ClusterCookie}=cluster_data:cluster_spec(cookie,HostName,ClusterName,ClusterSpec),
    Result=stop(PodNode,ClusterCookie,Appl),
   % io:format("Result ~p~n",[{?MODULE,?FUNCTION_NAME,?LINE,Result}]),
    Result.


stop(PodNode,ClusterCookie,Appl)->
    App=list_to_atom(Appl),
    dist_lib:cmd(PodNode,ClusterCookie,application,stop,[App],5000).

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
unload(HostName,ClusterName,PodName,Appl,ClusterSpec)->
    {ok,PodInfo}=pod_data:pod_info_by_name(HostName,ClusterName,PodName,ClusterSpec),
    PodNode=pod_data:pod(node,PodInfo),
    PodDir=pod_data:pod(dir,PodInfo),
    ApplDir=filename:join(PodDir,Appl),
    {ok,ClusterCookie}=cluster_data:cluster_spec(cookie,HostName,ClusterName,ClusterSpec),
    Result=unload(PodNode,ClusterCookie,ApplDir),
   % io:format("Result ~p~n",[{?MODULE,?FUNCTION_NAME,?LINE,Result}]),
    Result.


unload(PodNode,ClusterCookie,ApplDir)->
    dist_lib:rmdir_r(PodNode,ClusterCookie,ApplDir).


%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
is_running(HostName,ClusterName,PodName,Appl,ClusterSpec)->
    {ok,PodInfo}=pod_data:pod_info_by_name(HostName,ClusterName,PodName,ClusterSpec),
    PodNode=pod_data:pod(node,PodInfo),
    {ok,ClusterCookie}=cluster_data:cluster_spec(cookie,HostName,ClusterName,ClusterSpec),
    is_running(PodNode,ClusterCookie,Appl).


is_running(PodNode,ClusterCookie,Appl)->
    App=list_to_atom(Appl),
    Result=case dist_lib:cmd(PodNode,ClusterCookie,App,ping,[],5000) of
	       pang->
		   false;
	       pong->
		   true;
	       {badrpc,_}->
		   false
	   end,
    Result.

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
is_loaded(_HostName,_ClusterName,_PodName,_Appl,_ClusterSpec)->
    not_implemented.


