#include <amxmodx>
#include <reapi>
#include <SprLetters>

#define nullent 0
#define var_WordEnt var_owner
#define var_WordDir var_vuser1
#define var_WordText var_message
#define var_LetterSize var_fuser1
#define var_LetterText var_message
#include "SprLett-Core/Utils"

new const PLUG_NAME[] = "Sprite Letters";
new const PLUG_VER[] = "1.0.0";

new const INFO_TARGET_CLASSNAME[] = "info_target";
new const LETTER_CLASSNAME[] = "SprLetters_Letter";
new const WORD_CLASSNAME[] = "SprLetters_Word";

#define IsLetter(%1) FClassnameIs(%1,LETTER_CLASSNAME)
#define IsWord(%1) FClassnameIs(%1,WORD_CLASSNAME)
#define IsWordLetter(%1) (IsLetter(%1)&&IsWord(get_entvar(%1,var_WordEnt)))
#define IsWordOrLetter(%1) (IsLetter(%1)||IsWord(%1))

new SprParams[SprLett_Params] = {
    1.0,   // SL_P_Scale
    255.0, // SL_P_Alpha
    9.0,   // SL_P_Size
};
new Float:SprWordDir[3] = {1.0, 0.0, 0.0};
new Float:SprAngles[3] = {0.0, 0.0, 0.0};
new SprCharset[SprLett_CharsetData];

new bool:EditMode = false;
new Trie:Charsets;

public plugin_precache(){
    register_plugin(PLUG_NAME, PLUG_VER, "ArKaNeMaN");
    register_library(SL_LIB_NAME);

    Charsets = LoadCharsets();
    if(Charsets == Invalid_Trie)
        set_fail_state("[ERROR] Charsets not loaded.");

    if(!TrieGetArray(Charsets, "Default", SprCharset, SprLett_CharsetData))
        TrieGetFirstArray(Charsets, SprCharset, SprLett_CharsetData);
}

public plugin_init(){
    server_print(
        "[%s v%s] %d charsets loaded. Default charset: '%s'.",
        PLUG_NAME, PLUG_VER,
        TrieGetSize(Charsets),
        SprCharset[SL_CD_Name]
    );
}

/**
 * Перключает режим редактирования букв/слов
 *
 * @param State В какое состояние переключиться
 *
 * @noreturn
 */
EditToggle(const bool:State){
    if(State == EditMode)
        return;
    EditMode = State;
    
    new Ent = -1;
    while((Ent = rg_find_ent_by_class(Ent, LETTER_CLASSNAME)) > 0){
        if(IsEntRemoved(Ent))
            continue;
        set_entvar(Ent, var_solid, EditMode ? SOLID_SLIDEBOX : SOLID_TRIGGER);
    }
}

/**
 * Инициализация слова.
 *
 * @note Данная функция не строит слово. Для построения слова используется функция BuildWord
 *
 * @param Word   Слово, которое надо вывести
 * @param Origin Начальные коорды
 *
 * @return  Индекс ентити слова
 */
InitWord(const Word[], const Float:Origin[3]){
    new WordEnt = rg_create_entity(INFO_TARGET_CLASSNAME);
    if(is_nullent(WordEnt))
        return nullent;
        
    set_entvar(WordEnt, var_classname, WORD_CLASSNAME);
    set_entvar(WordEnt, var_origin, Origin);
    set_entvar(WordEnt, var_angles, SprAngles);
    set_entvar(WordEnt, var_scale, SprParams[SL_P_Scale]);
    set_entvar(WordEnt, var_renderamt, SprParams[SL_P_Alpha]);
    set_entvar(WordEnt, var_LetterSize, SprParams[SL_P_Size]);
    set_entvar(WordEnt, var_WordDir, SprWordDir);
    set_entvar(WordEnt, var_WordText, Word);

    return WordEnt;
}

/**
 * Строит слово исходя из параметров ентити слова
 *
 * @param WordEnt Индекс ентити слова
 *
 * @noreturn
 */
BuildWord(const WordEnt){
    if(!IsWord(WordEnt))
        return;
    
    set_entvar(WordEnt, var_effects, EF_NODRAW);
    set_entvar(WordEnt, var_flags, FL_DORMANT);
    set_entvar(WordEnt, var_WordEnt, WordEnt);

    new Float:Dir[3];
    get_entvar(WordEnt, var_WordDir, Dir);

    new Float:OffsetVec[3];
    VecMult(Dir, Float:get_entvar(WordEnt, var_LetterSize)*2.0, OffsetVec);

    new Word[WORD_MAX_LENGTH];
    get_entvar(WordEnt, var_WordText, Word, charsmax(Word));

    new Float:Origin[3];
    get_entvar(WordEnt, var_origin, Origin);

    new PrevLetterEnt = WordEnt;
    new Letter[LETTER_SIZE], Next = 0;
    while(GetLetterFromStr(Word, Letter, Next)){
        if(!equal(Letter, " ")){
            new LetterEnt = CreateLetter(Letter, Origin, true);
            if(is_nullent(LetterEnt)){
                log_amx("[WARNING] Can`t create letter '%s' for word.", Letter);
                continue;
            }

            MakeWordLetter(WordEnt, LetterEnt);
            set_entvar(LetterEnt, var_LetterText, Letter);
            set_entvar(PrevLetterEnt, var_chain, LetterEnt);
            PrevLetterEnt = LetterEnt;
        }
        VecSumm(Origin, OffsetVec, Origin);
    }

    // Замыкание списка
    set_entvar(PrevLetterEnt, var_chain, WordEnt);
}

/**
 * Настраивает букву исходя из параметров слова
 *
 * @param WordEnt   Индекс ентити слова
 * @param LetterEnt Индекс ентити буквы
 *
 * @noreturn
 */
MakeWordLetter(const WordEnt, const LetterEnt){
    SetEntSize(LetterEnt, get_entvar(WordEnt, var_LetterSize));
    copy_entvar_num(WordEnt, var_renderamt, LetterEnt);
    copy_entvar_num(WordEnt, var_scale, LetterEnt);
    copy_entvar_vec(WordEnt, var_angles, LetterEnt);

    set_entvar(LetterEnt, var_WordEnt, WordEnt);
}

/**
 * Получает индекс ентити слова
 *
 * @param Ent Индекс ентити буквы/слова
 *
 * @return Индекс ентити слова или 0 если слово не найдено
 */
GetWord(const Ent){
    if(IsWord(Ent))
        return Ent;
    if(IsWordLetter(Ent))
        return get_entvar(Ent, var_WordEnt);
    return nullent;
}

/**
 * Создаёт букву спрайтом
 *
 * @param Letter  Буква
 * @param Origin  Координаты
 * @param ForWord Если true, то не задаёт некотоыре параметры ентити
 *
 * @return          Индекс ентити созданной буквы
 */
CreateLetter(const Letter[LETTER_SIZE], const Float:Origin[3], const bool:ForWord = false){
    new Ent = rg_create_entity(INFO_TARGET_CLASSNAME);
    if(is_nullent(Ent))
        return nullent;

    set_entvar(Ent, var_classname, LETTER_CLASSNAME);
    set_entvar(Ent, var_model, SprCharset[SL_CD_SpriteFile]);
    set_entvar(Ent, var_modelindex, SprCharset[SL_CD_SpriteIndex]);
    set_entvar(Ent, var_movetype, MOVETYPE_FLY);
    set_entvar(Ent, var_solid, EditMode ? SOLID_SLIDEBOX : SOLID_TRIGGER);
    set_entvar(Ent, var_origin, Origin);
    set_entvar(Ent, var_rendermode, kRenderTransAdd);
    set_entvar(Ent, var_frame, float(GetCharNum(Letter)));

    if(!ForWord){
        set_entvar(Ent, var_renderamt, SprParams[SL_P_Alpha]);
        SetEntSize(Ent, SprParams[SL_P_Size]*SprParams[SL_P_Scale]);
        set_entvar(Ent, var_angles, SprAngles);
        set_entvar(Ent, var_scale, SprParams[SL_P_Scale]);
    }

    return Ent;
}

/**
 * Удаляет все буквы слова
 *
 * @param WordEnt Индекс ентити слова
 *
 * @noreturn
 */
DestroyWord(const WordEnt){
    if(!IsWord(WordEnt))
        return;
    new LetterEnt = WordEnt;
    while(WordIterNext(LetterEnt) != nullent)
        RemoveLetter(LetterEnt);
    set_entvar(WordEnt, var_chain, nullent);
}

/**
 * Удаляет слово
 *
 * @param Ent Индекс ентити слова или любой буквы слова
 *
 * @noreturn
 */
RemoveWord(Ent){
    new WordEnt = GetWord(Ent);
    if(WordEnt == nullent)
        return;
    DestroyWord(WordEnt);
    RgRemoveEnt(WordEnt);
}

/**
 * Удаляет букву
 *
 * @param LetterEnt Ентити буквы
 *
 * @noreturn
 */
RemoveLetter(const LetterEnt){
    if(!IsLetter(LetterEnt))
        return;
    RgRemoveEnt(LetterEnt);
}

/**
 * Получение номера символа из карты символов
 *
 * @note Если указанный символ не найден в карте функция вернёт номер первого символа (0)
 *
 * @param Char Символ
 *
 * @return Порядковый номер символа
 */
GetCharNum(const Char[]){
    new Num;
    return TrieGetCell(SprCharset[SL_CD_Map], Char, Num) ? Num-1 : 0;
}

/**
 * Возвращает следующий элемент слова
 *
 * @param Iterator Индекс ентити слова или буквы
 *
 * @return  Индекс ентити буквы или 0 если пройдены все буквы
 */
WordIterNext(&Iterator){
    if(!IsWordOrLetter(Iterator))
        return Iterator = nullent;

    Iterator = get_entvar(Iterator, var_chain);
    if(
        IsWord(Iterator) // Если следующий элемент слово - все буквы пройдены
        || !IsLetter(Iterator)
    ) Iterator = nullent;

    return Iterator;
}

#include "SprLett-Core/Natives"
#include "SprLett-Core/Configs"