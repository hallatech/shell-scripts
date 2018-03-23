Script facilities
=================

startWeblogic[server].sh
------------------------

*Note* These scripts use a pimped AdminServer instance in separate domains to reduce the overhead of having additional admin servers to managed servers

- function usage shows all runtime parameters and options
- process CLI parameters using shift mechanism, preset default values and override using CL parameters
- use ATG/OC layering. All layers are pre-built/generated into the EAR, and the default applied on startup. Extending the layering can be tested using -l or --layer option.
- use optional switching layering (non-switching vs switching)
- manipulate runtime memory configurations
- running locally with an ATG/OC installation may result in $ATG_HOME/home/localconfig/atg/dynamo/Configuration.properties being set or even installed OOTB. Clean up to avoid potential port conflict
- handle Endeca indexing so you only need to index on the first startup, otherwise it is a redundant startup activity, and can be initiated via Dynamo Admin if required.
- configure remote debugging, fast shutdown on Ctrl-C, different logging configurations per JDK version
- configure JRebel across major version architecture changes
- configure and enable Takipi monitoring
- use ATGLogColorizer
- enable background or foreground operation
- add protocol jar for WLS, add other optional jars on WLS pre-classpath