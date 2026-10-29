// G1R Cheat Menu: translations. Every text in the code is English. The menu passes titles, labels,
// values, hints and status lines through CM::T just before it draws them, which looks the whole
// text up in the table of the game's current language (Lang\CMLang_<code>.as, made by
// tools\gen-lang.py from translations\strings.json). Texts with changing parts are written as
// templates with {0}, {1}, ... and filled with CM::F, which translates the parts as well.
// A text without a translation is shown in English.

// the table in use, in the class default object so all menus share it
class UCMLang : UObject
{
    FString Code; // "" until the first lookup
    TMap<FString, FString> Strings;
}

namespace CM
{
    UCMLang Lang()
    {
        return Cast<UCMLang>(UCMLang::StaticClass().GetDefaultObject());
    }

    // the menu's language for the game's: the first two letters of its culture ("pt-BR" gives pt)
    FString LanguageCode()
    {
        FString code = Internationalization::GetCurrentLanguage().Left(2).ToLower();
        if (code == "de" || code == "fr" || code == "it" || code == "es" || code == "pt" || code == "pl" || code == "ru")
            return code;
        return "en";
    }

    // loads the table of the game's language; cheap when it has not changed, so the menu calls it
    // before every repaint and follows a language switch in the game's settings
    void SyncLanguage()
    {
        UCMLang lang = Lang();
        FString code = LanguageCode();
        if (lang.Code == code)
            return;
        lang.Code = code;
        lang.Strings.Reset();
        if (code == "de")
            CMLang::De(lang.Strings);
        else if (code == "fr")
            CMLang::Fr(lang.Strings);
        else if (code == "it")
            CMLang::It(lang.Strings);
        else if (code == "es")
            CMLang::Es(lang.Strings);
        else if (code == "pt")
            CMLang::Pt(lang.Strings);
        else if (code == "pl")
            CMLang::Pl(lang.Strings);
        else if (code == "ru")
            CMLang::Ru(lang.Strings);
    }

    FString T(FString En)
    {
        UCMLang lang = Lang();
        if (lang.Code == "")
            SyncLanguage();
        if (En != "" && lang.Strings.Contains(En))
            return lang.Strings[En];
        return En;
    }

    // a template with {0}..{3}, translated, its parts translated and filled in
    FString F(FString En, FString A, FString B = "", FString C = "", FString D = "")
    {
        return T(En).Replace("{0}", T(A)).Replace("{1}", T(B)).Replace("{2}", T(C)).Replace("{3}", T(D));
    }
}
