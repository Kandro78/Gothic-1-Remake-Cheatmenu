// G1R Cheat Menu: World page. Time of day, freezing time, weather, game speed and the story chapter.

// switches that last for the whole game session, like UCMPlayerState
class UCMWorldState : UObject
{
    bool bFrozen = false;
    float Speed = 1;
}

class UCMWorldPage : UCMPage
{
    UCMWorldState S() const
    {
        return Cast<UCMWorldState>(UCMWorldState::StaticClass().GetDefaultObject());
    }

    FString GetTitle() const override
    {
        return "World";
    }

    void Build(TArray<FCMItem>& Items) override
    {
        Items.Add(CM::Item("Time (1 hour steps)", ECMKind::Value, n"Time"));
        Items.Add(CM::Item("Freeze time", ECMKind::Toggle, n"Freeze"));
        Items.Add(CM::Item("Weather", ECMKind::Value, n"Weather"));
        Items.Add(CM::Item("Game speed", ECMKind::Value, n"Speed"));
        // changing the chapter is hard to undo: only Left / Right change it, Enter does nothing
        FCMItem chapter = CM::Item("Story chapter", ECMKind::Value, n"Chapter");
        chapter.bEnterIgnored = true;
        Items.Add(chapter);
    }

    FString Clock()
    {
        UGameTimeSubsystem time = UGameTimeSubsystem::Get();
        if (time == nullptr || CM::Hero() == nullptr)
            return "-";
        int day = Math::FloorToInt(time.GetCurrentGameTime().TotalSeconds / 86400);
        FClockTime clock = time.GetCurrentClockTime();
        FString minute = "" + clock.Minute;
        if (minute.Len() < 2)
            minute = "0" + minute;
        FString hour = "" + clock.Hour;
        if (hour.Len() < 2)
            hour = "0" + hour;
        return CM::F("Day {0}, {1}:{2}", "" + day, hour, minute);
    }

    AGothicUltraDynamicController Weather()
    {
        TArray<AActor> actors;
        GetAllActorsOfClass(AGothicUltraDynamicController::StaticClass(), actors);
        return actors.Num() > 0 ? Cast<AGothicUltraDynamicController>(actors[0]) : nullptr;
    }

    // the weathers in the order Left / Right go through them
    TArray<EWeather> Weathers()
    {
        TArray<EWeather> list;
        list.Add(EWeather::Sunny);
        list.Add(EWeather::Cloudy);
        list.Add(EWeather::Rain_Level1);
        list.Add(EWeather::Rain_Level2);
        list.Add(EWeather::Rain_Level3);
        return list;
    }

    FString WeatherName(EWeather Weather)
    {
        if (Weather == EWeather::Sunny)
            return "Sunny";
        if (Weather == EWeather::Cloudy)
            return "Cloudy";
        if (Weather == EWeather::Rain_Level1)
            return "Light rain";
        if (Weather == EWeather::Rain_Level2)
            return "Rain";
        if (Weather == EWeather::Rain_Level3)
            return "Storm";
        return "-";
    }

    TArray<float> Speeds()
    {
        TArray<float> list;
        list.Add(0.25);
        list.Add(0.5);
        list.Add(1);
        list.Add(2);
        list.Add(3);
        list.Add(5);
        return list;
    }

    FString GetValue(FName Id) override
    {
        if (Id == n"Time")
            return Clock();
        if (Id == n"Freeze")
            return CM::OnOff(S().bFrozen);
        if (Id == n"Weather")
        {
            AGothicUltraDynamicController ctrl = Weather();
            return ctrl != nullptr ? WeatherName(ctrl.GetCurrentWeather()) : "-";
        }
        if (Id == n"Speed")
            return CM::Num(S().Speed) + "x";
        if (Id == n"Chapter")
        {
            UGameStory story = UGameStory::GetMainStory();
            return story != nullptr && CM::Hero() != nullptr ? "" + story.GetChapter() : "-";
        }
        return "";
    }

    FString Activate(FName Id, int Dir) override
    {
        if (CM::Hero() == nullptr)
            return CM::NotInGame;
        if (Id == n"Time")
            return ShiftTime(Dir);
        if (Id == n"Freeze")
        {
            UGameTimeSubsystem time = UGameTimeSubsystem::Get();
            if (time == nullptr)
                return CM::NotInGame;
            S().bFrozen = !S().bFrozen;
            if (S().bFrozen)
                time.FreezeTime();
            else
                time.UnfreezeTime();
            return S().bFrozen ? "Time frozen" : "Time running";
        }
        if (Id == n"Weather")
        {
            AGothicUltraDynamicController ctrl = Weather();
            if (ctrl == nullptr)
                return "Weather controller not found";
            TArray<EWeather> list = Weathers();
            int idx = Math::Max(list.FindIndex(ctrl.GetCurrentWeather()), 0);
            EWeather next = list[(idx + Dir + list.Num()) % list.Num()];
            ctrl.SetCurrentWeatherImmediate(next);
            return CM::F("Weather: {0}", WeatherName(next));
        }
        if (Id == n"Speed")
        {
            TArray<float> list = Speeds();
            int idx = Math::Max(list.FindIndex(S().Speed), 2);
            S().Speed = list[Math::Clamp(idx + Dir, 0, list.Num() - 1)];
            Gameplay::SetGlobalTimeDilation(S().Speed);
            return CM::F("Game speed: {0}x", CM::Num(S().Speed));
        }
        if (Id == n"Chapter")
        {
            UGameStory story = UGameStory::GetMainStory();
            if (story == nullptr)
                return CM::NotInGame;
            int cur = story.GetChapter();
            int target = Math::Clamp(cur + Dir, 1, 6);
            if (target == cur)
                return CM::F("Chapter: {0}", "" + cur);
            story.ChangeChapter(target);
            return CM::F("Chapter: {0} -> {1}", "" + cur, "" + story.GetChapter());
        }
        return "";
    }

    FString ShiftTime(int Dir)
    {
        UGameTimeSubsystem time = UGameTimeSubsystem::Get();
        if (time == nullptr)
            return CM::NotInGame;
        if (Dir > 0)
        {
            time.SkipTime(FInGameTime::FromHours(1));
        }
        else
        {
            float64 total = time.GetCurrentGameTime().TotalSeconds;
            if (total < 3600)
                return "Cannot go back before day 0";
            total -= 3600;
            int day = Math::FloorToInt(total / 86400);
            float64 rest = total - day * 86400.0;
            int hour = Math::FloorToInt(rest / 3600);
            int minute = Math::FloorToInt((rest - hour * 3600.0) / 60);
            time.SetCurrentGameTime(day, hour, minute, 0);
        }
        return CM::F("Time: {0}", Clock());
    }
}
