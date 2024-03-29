/**
 * [SprLett] Editor: Utils
 */

#include <amxmodx>

#define Lang(%1) \
    fmt("%l", %1)

#define CHECK_WORD(%1) \
    if(!SprLett_Is(gSelWord[%1], SL_Is_Word)){\
        client_print(%1, print_center, Lang("CMD_WORD_NOT_SELECTED"));\
        return;\
    }

#define CMD_CHECK_ARGC(%1,%2) \
    new NULL_ARG = GetNullArg(); \
    if(read_argc()-NULL_ARG < %2+1){\
        client_print(%1, print_center, Lang("CMD_INVALID_PARAMS"));\
        return;\
    }

#define CMD_CHECK_ACCESS(%1) \
    if(!(get_user_flags(%1) & EDIT_ACCESS)){\
        client_print(%1,print_center, Lang("CMD_NO_ACCESS"));\
        return;\
    }

RegisterClCmds(const Cmd[], const Handler[], const ChatCmdPrefix[] = "/"){
    register_clcmd(Cmd, Handler);
    register_clcmd(fmt("say %s%s", ChatCmdPrefix, Cmd), Handler);
    register_clcmd(fmt("say_team %s%s", ChatCmdPrefix, Cmd), Handler);
}

GetNullArg(){
    static cmd[64];
    read_argv(0, cmd, charsmax(cmd));
    if(
        equal(cmd, "say")
        || equal(cmd, "say_team")
    ) return 1;
    return 0;
}
