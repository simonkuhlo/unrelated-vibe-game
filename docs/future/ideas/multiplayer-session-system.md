# Multiplayer session system   
## Summary   
A "multiplayer session" (session) acts as the core of a multiplayer session. It can control / dictate / sync the state of certain other systems, like the map loader or the gamemode loader. A session can have the following states:   
## Session states   
### Ingame   
Main phase of the session. Map and gamemode are loaded, gamemode is started. Connected players can play the game and late joiners get to synchronize and then handeled depending on / by the gamemode. When the hosts' / servers' gamemode module signals that the game is over, the sesion should return to the preparation phase through loading out. The host can also force the return to preparation without waiting for the gamemode.   
### Preparation    
The preparation phase can be used to select / set the desired map and gamemode on the host. Once everything is set up the host can confirm and enter loading in state. During the preparation phase the players / clients can send / sync state updates like display name, selected character, etc. to the host / server, which then acknowledges and propagates the changes to other clients.   
### Loading in (unsure)   
Session is preparing to start a game. During this phase, gamemode and map are already locked and cannot be changed anymore until the lobby is back in prep mode. Clients can also start loading into the configured map, since it's locked, but they might have to wait for the lobby at some point (sync, etc.). Before starting the game, the lobby will also wait for a set amount of time until every client stated that it finished loading and is ready. If anyone takes too long, the lobby will start the game regardless.   
### Loading out (unsure)   
Session is being freed up from a previous game. After, it will automatically switch to the preparation phase. It is not possible to load into a new game during this state   
| Session Phase / State   <br> | Map & Gamemode select   <br> | Map loader status   <br> | Gamemode loader status   <br> | Client actions   <br> |
|:-----------------------------|:-------------------------------|:---------------------------|:------------------------------|:----------------------|
|           Preparation   <br> |      selectable by host   <br> |                free   <br> |                   free   <br> |        allowed   <br> |
|            Loading in   <br> |                  locked   <br> |             loading   <br> |                loading   <br> |         locked   <br> |
|                Ingame   <br> |                  locked   <br> |              loaded   <br> |        loaded, started   <br> |        allowed   <br> |
|           Loading out   <br> |                  locked   <br> |           unloading   <br> |              unloading   <br> |         locked   <br> |
