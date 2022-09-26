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
-module(cluster).   
 
-export([
	 start/5,
	 stop/4,

	 create_node/4,
	 delete_node/4,
	 availble/3,
	 not_availble/3,
	 connect/3
	]).

-export([
	 hostname/3
	]).


-record(cluster,{
		 name,
		 cookie,
		 dir,
		 hostname,
		 num_pods,
		 pods_info
		}).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
% {ClusterNodeName,Cookie,ClusterDir,HostName,NumPods,PodsInfo}
hostname(Key,HostName,ClusterInfoList)->
    Info=[I||I<-ClusterInfoList,
		       I#cluster.hostname=:=HostName],   
    case Info of
	[]->
	    {error,[hostname_eexists,HostName]};
        [I]->
	    case Key of
		cookie->
		    I#cluster.cookie;
		dir->
		    I#cluster.dir;
		num_pods->
		    I#cluster.num_pods;
		pods_info->
		    I#cluster.pods_info;
		Key ->
		    {error,[key_eexists,Key]}
	    end
    end.


%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------

start(HostNames,ClusterNodeName,ClusterCookie,ClusterDir,NumPodsPerHost)->
    start(HostNames,ClusterNodeName,ClusterCookie,ClusterDir,NumPodsPerHost,[]).

start([],_ClusterNodeName,_ClusterCookie,_ClusterDir,_NumPodsPerHost,Acc)->
    Acc; 
start([HostName|T],ClusterNodeName,ClusterCookie,ClusterDir,NumPodsPerHost,Acc)->
    NewAcc=case cluster:create_node(HostName,ClusterNodeName,ClusterCookie,ClusterDir) of
	       {error,Reason}->
		   [{error,Reason}|Acc];
	       {ok,_}->
		   ClusterNode=list_to_atom(ClusterNodeName++"@"++HostName),
		   PodArgs=" -setcookie "++ClusterCookie,
		   PodNodeNames=[ClusterNodeName++"_"++integer_to_list(N)||N<-lists:seq(0,NumPodsPerHost)],
		 %  _PodInfo=[{ClusterNode,ClusterCookie,HostName,
		%	     PodNodeName,filename:join(ClusterDir,PodNodeName),
		%	     PodArgs,list_to_atom(PodNodeName++"@"++HostName)}||PodNodeName<-PodNodeNames],
		   PodNodeList=[pod:create(ClusterNode,ClusterCookie,HostName,PodNodeName,filename:join(ClusterDir,PodNodeName),PodArgs)||PodNodeName<-PodNodeNames],
		   
		   [#cluster{name=ClusterNodeName,cookie=ClusterCookie,dir=ClusterDir,hostname=HostName,num_pods=NumPodsPerHost,pods_info=PodNodeList}|Acc]
	   end,
    start(T,ClusterNodeName,ClusterCookie,ClusterDir,NumPodsPerHost,NewAcc).    

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------

stop(HostNames,ClusterNodeName,ClusterCookie,ClusterDir)->
    [delete_node(HostName,ClusterNodeName,ClusterCookie,ClusterDir)||HostName<-HostNames].
	      
%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
create_node(HostName,ClusterNodeName,ClusterCookie,ClusterDir)->
    Result=case dist_lib:start_node(HostName,ClusterNodeName,ClusterCookie," -detached  ") of
	       {error,Reason}->
		   {error,[Reason,HostName,ClusterNodeName,ClusterCookie]};
	       true ->
		   ClusterNode=list_to_atom(ClusterNodeName++"@"++HostName),
		   dist_lib:rmdir_r(ClusterNode,ClusterCookie,ClusterDir),
		   case dist_lib:mkdir(ClusterNode,ClusterCookie,ClusterDir) of
		       {error,Reason}->
			   {error,[Reason,HostName,ClusterNodeName,ClusterCookie]};
		       ok->
			   case dist_lib:cmd(ClusterNode,ClusterCookie,filelib,is_dir,[ClusterDir],5000) of
			       false->
				   {error,[cluster_dir_eexists,ClusterDir,HostName,ClusterNodeName,ClusterCookie]};
			       true->
				   {ok,{HostName,ClusterNodeName,ClusterNode,ClusterCookie,ClusterDir}}
			   end
		   end
	   end,
    Result.

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------

delete_node(HostName,ClusterNodeName,ClusterCookie,ClusterDir)->
    ClusterNode=list_to_atom(ClusterNodeName++"@"++HostName),
    dist_lib:rmdir_r(ClusterNode,ClusterCookie,ClusterDir),
    dist_lib:stop_node(HostName,ClusterNodeName,ClusterCookie).

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
availble(HostNames,ClusterNodeName,ClusterCookie)->
    {Available,_}=connect(HostNames,ClusterNodeName,ClusterCookie),
    Available.

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
not_availble(HostNames,ClusterNodeName,ClusterCookie)->
    {_,NotAvailable}=connect(HostNames,ClusterNodeName,ClusterCookie),
    NotAvailable.

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
connect(HostNames,ClusterNodeName,ClusterCookie)->
    [ClusterNode1|T]=[list_to_atom(ClusterNodeName++"@"++HostName)||HostName<-HostNames],
    R=[{Node,dist_lib:cmd(ClusterNode1,ClusterCookie,net_adm,ping,[Node],5000)}||Node<-T],
    Available=[ClusterNode1|[Node||{Node,pong}<-R]],
    NotAvailable=[Node||{Node,pang}<-R],
    {Available,NotAvailable}.
