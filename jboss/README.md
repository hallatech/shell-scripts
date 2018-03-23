Script facilities
=================

startJBoss[server].sh
---------------------

- function usage shows all runtime parameters and options
- process CLI parameters using shift mechanism, preset default values and override using CL parameters
- use ATG/OC layering. All layers are pre-built/generated into the EAR, and the default applied on startup. Extending the layering can be tested using -l or --layer option
- manipulate runtime memory configurations
- running locally with an ATG/OC installation may result in $ATG_HOME/home/localconfig/atg/dynamo/Configuration.properties being set or even installed OOTB. Clean up to avoid potential port conflict
- handle Endeca indexing so you only need to index on the first startup, otherwise it is a redundant startup activity, and can be initiated via Dynamo Admin if required.
- configure remote debugging, fast shutdown on Ctrl-C, different logging configurations per JDK version
- configure JRebel across major version architecture changes
- use ATGLogColorizer
- enable background or foreground operation

stop[server].sh
---------------
- simple background stop scripts
- handle optional server names
- find and kill related PID
