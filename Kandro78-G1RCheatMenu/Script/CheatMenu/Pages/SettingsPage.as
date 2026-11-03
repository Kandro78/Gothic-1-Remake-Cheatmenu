// G1R Cheat Menu: Settings page. The key that opens the menu and the game speed key (switches the
// game speed between 1x and the last other speed set on the World page), kept across saves and game
// starts.

class UCMKeySettings : USaveGame
{
    UPROPERTY()
    FKey MenuKey; // none: F7
    UPROPERTY()
    FKey SpeedKey; // none: off
}

// the keys for the whole game session, like UCMWorldState. Only the values are kept: a save game
// object held here was freed by the garbage collector, and the next key press crashed the game (2.2.0)
class UCMKeySettingsState : UObject
{
    bool bLoaded = false;
    FKey MenuKey;
    FKey SpeedKey;
}

namespace CMKeys
{
    const FString Slot = "Kandro78-G1RCheatMenu-Keys";

    // the keys both can be set to; the menu's navigation keys and the game's quicksave (F5) and
    // quickload (F9) are left out
    TArray<FKey> Choices()
    {
        TArray<FKey> list;
        list.Add(EKeys::F6);
        list.Add(EKeys::F7);
        list.Add(EKeys::F8);
        list.Add(EKeys::F10);
        list.Add(EKeys::F11);
        list.Add(EKeys::Insert);
        list.Add(EKeys::Delete);
        list.Add(EKeys::NumPadZero);
        list.Add(EKeys::Add);
        list.Add(EKeys::Subtract);
        list.Add(EKeys::Multiply);
        list.Add(EKeys::Divide);
        return list;
    }

    FString Label(FKey Key)
    {
        if (!Key.IsValid())
            return CM::OnOff(false);
        if (Key == EKeys::NumPadZero)
            return "Num 0";
        if (Key == EKeys::Add)
            return "Num +";
        if (Key == EKeys::Subtract)
            return "Num -";
        if (Key == EKeys::Multiply)
            return "Num *";
        if (Key == EKeys::Divide)
            return "Num /";
        return Key.KeyName.ToString();
    }

    UCMKeySettingsState Get()
    {
        UCMKeySettingsState state = Cast<UCMKeySettingsState>(UCMKeySettingsState::StaticClass().GetDefaultObject());
        if (!state.bLoaded)
        {
            state.bLoaded = true;
            UCMKeySettings saved = Cast<UCMKeySettings>(Gameplay::LoadGameFromSlot(Slot, 0));
            if (saved != nullptr)
            {
                state.MenuKey = saved.MenuKey;
                state.SpeedKey = saved.SpeedKey;
            }
        }
        return state;
    }

    bool Save()
    {
        UCMKeySettings saved = Cast<UCMKeySettings>(Gameplay::CreateSaveGameObject(UCMKeySettings::StaticClass()));
        if (saved == nullptr)
            return false;
        saved.MenuKey = Get().MenuKey;
        saved.SpeedKey = Get().SpeedKey;
        return Gameplay::SaveGameToSlot(saved, Slot, 0);
    }

    FKey MenuKey()
    {
        FKey key = Get().MenuKey;
        return key.IsValid() ? key : EKeys::F7;
    }

    FKey SpeedKey()
    {
        return Get().SpeedKey;
    }

    // holding F7 brings the menu back for players who forgot the key they set (a reinstall keeps
    // it: Steam Cloud restores the slot)
    FString ResetMenuKey()
    {
        UCMKeySettingsState settings = Get();
        settings.MenuKey = EKeys::F7;
        if (settings.SpeedKey == EKeys::F7)
            settings.SpeedKey = FKey();
        if (!Save())
            return "Set for this session only: the slot could not be written";
        return CM::F("Menu key: {0}", Label(EKeys::F7));
    }

    // the next key after Current in Dir, skipping Taken (the other setting's key); bAllowNone adds
    // "off" before the first key
    FKey Next(FKey Current, int Dir, FKey Taken, bool bAllowNone)
    {
        TArray<FKey> list = Choices();
        if (bAllowNone)
            list.Insert(FKey(), 0);
        list.Remove(Taken);
        int idx = Math::Max(list.FindIndex(Current), 0);
        return list[(idx + Dir + list.Num()) % list.Num()];
    }
}

class UCMSettingsPage : UCMPage
{
    FString GetTitle() const override
    {
        return "Settings";
    }

    void Build(TArray<FCMItem>& Items) override
    {
        Items.Add(CM::Item("Menu key", ECMKind::Value, n"MenuKey"));
        Items.Add(CM::Item("Game speed key", ECMKind::Value, n"SpeedKey"));
    }

    FString GetValue(FName Id) override
    {
        if (Id == n"MenuKey")
            return CMKeys::Label(CMKeys::MenuKey());
        if (Id == n"SpeedKey")
            return CMKeys::Label(CMKeys::SpeedKey());
        return "";
    }

    FString Activate(FName Id, int Dir) override
    {
        UCMKeySettingsState settings = CMKeys::Get();
        FString status;
        if (Id == n"MenuKey")
        {
            settings.MenuKey = CMKeys::Next(CMKeys::MenuKey(), Dir, settings.SpeedKey, false);
            status = CM::F("Menu key: {0}", CMKeys::Label(settings.MenuKey));
        }
        else if (Id == n"SpeedKey")
        {
            settings.SpeedKey = CMKeys::Next(settings.SpeedKey, Dir, CMKeys::MenuKey(), true);
            status = CM::F("Game speed key: {0}", CMKeys::Label(settings.SpeedKey));
        }
        else
            return "";
        if (!CMKeys::Save())
            return "Set for this session only: the slot could not be written";
        return status;
    }
}
