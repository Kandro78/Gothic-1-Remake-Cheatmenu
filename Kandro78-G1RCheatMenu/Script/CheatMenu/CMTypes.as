// G1R Cheat Menu: shared types and helpers.
// A page is a UCMPage subclass. The menu asks it for its entries (Build), the text in the right
// column (GetValue), runs Enter / Left / Right on an entry (Activate) and calls Tick ten times a
// second while a save is loaded, for cheats that have to be kept up (mana, ammo, ...).

enum ECMKind
{
    Page,   // Enter opens SubPage
    Toggle, // Enter switches it on / off
    Action, // Enter runs it
    Value   // Left / Right change it, Enter counts as Right
}

struct FCMItem
{
    FString Label;
    ECMKind Kind = ECMKind::Action;
    FName Id;
    UCMPage SubPage;
    bool bEnterIgnored = false; // a Value only Left / Right change (Enter would be hard to undo)
}

class UCMPage : UObject
{
    int Selected = 0; // the selected entry, kept when the page is left so it opens there again

    FString GetTitle() const
    {
        return "";
    }

    // the footer hint; empty uses the default one
    FString GetHint() const
    {
        return "";
    }

    void Build(TArray<FCMItem>& Items)
    {
    }

    FString GetValue(FName Id)
    {
        return "";
    }

    // Dir: 0 for Enter, -1 / +1 for Left / Right. Returns the status line text.
    FString Activate(FName Id, int Dir)
    {
        return "";
    }

    void Tick(float DeltaSeconds)
    {
    }

    // the game is about to save: put back values the cheats hold, so they never end up in a save
    // (the next tick sets them again)
    void BeforeSave()
    {
    }
}

namespace CM
{
    const FString NotInGame = "Not in a running game";

    FCMItem Item(FString Label, ECMKind Kind, FName Id)
    {
        FCMItem item;
        item.Label = Label;
        item.Kind = Kind;
        item.Id = Id;
        return item;
    }

    FCMItem PageItem(FString Label, UCMPage SubPage)
    {
        FCMItem item;
        item.Label = Label;
        item.Kind = ECMKind::Page;
        item.SubPage = SubPage;
        return item;
    }

    FString OnOff(bool bOn)
    {
        return bOn ? "ON" : "OFF";
    }

    // 1, 1.5, 2.5 ...: one decimal at most, none for whole numbers
    FString Num(float Value)
    {
        int tenths = Math::RoundToInt(Value * 10.0);
        int whole = Math::IntegerDivisionTrunc(tenths, 10);
        if (tenths % 10 == 0)
            return "" + whole;
        return "" + whole + "." + Math::Abs(tenths % 10);
    }

    // FLinearColor from the 0-255 sRGB values a screenshot of the game shows
    FLinearColor Srgb(float R, float G, float B, float A = 1.0)
    {
        return FLinearColor(Linear(R), Linear(G), Linear(B), A);
    }

    float Linear(float C)
    {
        float c = C / 255.0;
        return c <= 0.04045 ? c / 12.92 : Math::Pow((c + 0.055) / 1.055, 2.4);
    }

    AGothicCharacter Hero()
    {
        return Cast<AGothicCharacter>(Gameplay::GetPlayerCharacter(0));
    }

    UGothicAbilitySystemComponent HeroASC()
    {
        AGothicCharacter hero = Hero();
        return hero != nullptr ? Cast<UGothicAbilitySystemComponent>(hero.AbilitySystemComponent) : nullptr;
    }

    // current value of a hero attribute, Default when there is no hero
    float Attr(TSubclassOf<UAngelscriptAttributeSet> Set, FName Name, float Default = -1.0)
    {
        UGothicAbilitySystemComponent asc = HeroASC();
        if (asc == nullptr)
            return Default;
        return asc.GetAttributeCurrentValue(Set, Name, Default);
    }

    float BaseAttr(TSubclassOf<UAngelscriptAttributeSet> Set, FName Name, float Default = -1.0)
    {
        UGothicAbilitySystemComponent asc = HeroASC();
        float32 value = float32(Default);
        if (asc == nullptr || !asc.TryGetAttributeBaseValue(Set, Name, value))
            return Default;
        return value;
    }

    bool SetAttr(TSubclassOf<UAngelscriptAttributeSet> Set, FName Name, float Value)
    {
        UGothicAbilitySystemComponent asc = HeroASC();
        return asc != nullptr && asc.TrySetAttributeBaseValue(Set, Name, Value);
    }

    // sets Name to MaxName; writes only when the value differs
    bool Fill(TSubclassOf<UAngelscriptAttributeSet> Set, FName Name, FName MaxName)
    {
        float max = Attr(Set, MaxName);
        if (max < 0)
            return false;
        if (Attr(Set, Name) < max)
            return SetAttr(Set, Name, max);
        return true;
    }

    UCombatConfig CombatConfig()
    {
        return Cast<UCombatConfig>(UCombatConfig::StaticClass().GetDefaultObject());
    }
}
