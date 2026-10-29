// G1R Cheat Menu: Items page. Quick items on the page itself, and a list page per kind of item.
// Item classes are found by name in the game's script data, so an item a game update drops is
// left out instead of breaking the mod. Names are read from each item (m_Name), so they follow the
// game language.

struct FCMGift
{
    FString Label;
    TSubclassOf<UItemDefinition> Class;
    int Count = 1;
}

namespace CMItems
{
    // the item class named Name (without the U prefix), or nullptr
    TSubclassOf<UItemDefinition> Find(FString Name)
    {
        UClass found = UClass::FindClassFromName(FName(Name));
        if (found == nullptr)
            found = UClass::FindClassFromName(FName("U" + Name));
        if (found == nullptr || !found.IsChildOf(UItemDefinition::StaticClass()))
            return nullptr;
        return found;
    }

    // the item's name in the game language, "" when it has none
    FString Name(TSubclassOf<UItemDefinition> Class)
    {
        UGothicObjectDefinition cdo = Cast<UGothicObjectDefinition>(Class.Get().GetDefaultObject());
        return cdo != nullptr ? cdo.m_Name.ToString() : "";
    }

    FString Give(FCMGift Gift)
    {
        AGothicCharacter hero = CM::Hero();
        if (hero == nullptr)
            return CM::NotInGame;
        UInventoryComponent inventory = hero.GetInventory();
        if (inventory == nullptr)
            return "Inventory not found";
        inventory.AddItemOfClass(Gift.Class, Gift.Count);
        return CM::F("Added: {0}", Gift.Label);
    }

    FString GiveAll(TArray<FCMGift> Gifts)
    {
        if (CM::Hero() == nullptr)
            return CM::NotInGame;
        int given = 0;
        for (FCMGift gift : Gifts)
        {
            if (Give(gift).StartsWith("Added"))
                given++;
        }
        return CM::F("Added {0} of {1} items", "" + given, "" + Gifts.Num());
    }
}

// one kind of item; the list is read from the game when the page first opens
class UCMItemListPage : UCMPage
{
    FString Title;
    FString AllLabel;  // the "give all" entry, none when empty
    FString Prefix;    // put before every id
    FString Ids;       // class names without the prefix, separated by spaces
    int Count = 1;
    bool bSorted = true;    // by name; otherwise in the order of Ids
    bool bDistinct = false; // items sharing a name are different items (keys): each is listed with its id
    TArray<FCMGift> Gifts;
    bool bRead = false;

    FString GetTitle() const override
    {
        return Title;
    }

    FString GetHint() const override
    {
        return "[Enter] Add   [Backspace] Back   [F7] Close";
    }

    void Read()
    {
        bRead = true;
        TArray<FString> ids;
        Ids.ParseIntoArray(ids, " ", true);
        TArray<FCMGift> found;
        TArray<FString> names;
        for (FString id : ids)
        {
            TSubclassOf<UItemDefinition> cls = CMItems::Find(Prefix + id);
            if (!cls.IsValid())
                continue;
            FString name = CMItems::Name(cls);
            if (name == "" || name.StartsWith("It"))
                name = id.Replace("_", " ");
            if (!bDistinct && names.Contains(name))
                continue; // copies of a weapon for story scenes
            FCMGift gift;
            gift.Label = name;
            gift.Class = cls;
            gift.Count = Count;
            found.Add(gift);
            names.Add(name);
        }
        // names several distinct items share get the item's id
        for (FCMGift& gift : found)
        {
            int same = 0;
            for (FString name : names)
            {
                if (name == gift.Label)
                    same++;
            }
            if (same > 1)
            {
                FString id = gift.Class.Get().GetName().ToString();
                if (id.StartsWith("It") && id.Mid(4, 1) == "_")
                    id = id.RightChop(5);
                gift.Label += " (" + id.Replace("_", " ") + ")";
            }
        }
        Gifts.Reset();
        if (!bSorted)
        {
            Gifts = found;
            return;
        }
        // sort by label: sort "label<tab>index" keys (a tab sorts before any letter or space, so
        // "Axe" comes before "Axe of ..."), then put the gifts in that order
        TArray<FString> keys;
        for (int i = 0; i < found.Num(); i++)
            keys.Add(found[i].Label + "\t" + i);
        keys.Sort();
        for (FString key : keys)
        {
            FString left;
            FString right;
            key.Split("\t", left, right, ESearchCase::CaseSensitive, ESearchDir::FromEnd);
            Gifts.Add(found[String::Conv_StringToInt(right)]);
        }
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (!bRead || Gifts.Num() == 0)
            Read();
        if (AllLabel != "" && Gifts.Num() > 0)
            Items.Add(CM::Item(AllLabel, ECMKind::Action, n"All"));
        for (int i = 0; i < Gifts.Num(); i++)
            Items.Add(CM::Item(Gifts[i].Label, ECMKind::Action, FName("Gift" + i)));
    }

    FString Activate(FName Id, int Dir) override
    {
        if (Id == n"All")
            return CMItems::GiveAll(Gifts);
        FString s = Id.ToString();
        int i = String::Conv_StringToInt(s.RightChop(4));
        if (!s.StartsWith("Gift") || i < 0 || i >= Gifts.Num())
            return "";
        return CMItems::Give(Gifts[i]);
    }
}

class UCMItemsPage : UCMPage
{
    TArray<UCMItemListPage> Lists;
    TArray<FCMGift> Quick;

    FString GetTitle() const override
    {
        return "Items";
    }

    UCMItemListPage AddList(FString Title, FString AllLabel, FString Prefix, int Count, FString Ids)
    {
        UCMItemListPage page = Cast<UCMItemListPage>(NewObject(this, UCMItemListPage::StaticClass()));
        page.Title = Title;
        page.AllLabel = AllLabel;
        page.Prefix = Prefix;
        page.Count = Count;
        page.Ids = Ids;
        Lists.Add(page);
        return page;
    }

    void AddQuick(FString Label, FString Id, int Count)
    {
        FCMGift gift;
        gift.Label = Label;
        gift.Class = CMItems::Find(Id);
        gift.Count = Count;
        if (gift.Class.IsValid())
            Quick.Add(gift);
    }

    void Fill()
    {
        // rune item classes are ItAr_Rune_<name>; the two quest-only Milten fireball variants are left out
        UCMItemListPage runes = AddList("Runes", "All runes", "ItAr_Rune_", 1,
            "Light Heal FireBolt FireBall StormOfFire FireRain Pyrokinesis IceBolt IceBlock IceWave " +
            "BallLightning ChainLightning FistOfWind StormFist Telekinesis Sleep Charm Control " +
            "DeathToTheUndead BreathOfDeath UrizielWaveOfDeath TeleportToMagiciansOfFire " +
            "TeleportToMagiciansOfWater TeleportToSwampCamp TeleportToNecromancer TeleportToSunkenTower");
        runes.bSorted = false;
        // a scroll is used up when cast, so each gives several
        UCMItemListPage scrolls = AddList("Scrolls", "All scrolls", "ItAr_Scroll_", 5,
            "Light Heal FireBolt FireBall StormOfFire FireRain Pyrokinesis IceBolt IceBlock IceWave " +
            "BallLightning ChainLightning FistOfWind StormFist Telekinesis Sleep Charm Control Fear Shrink " +
            "DeathToTheUndead InnosPray SummonSkeletons SummonGolem SummonDemon SummonArmyOfDarkness " +
            "TransformMeatbug TransformBloodfly TransformMolerat TransformScavenger TransformWolf TransformBiter " +
            "TransformLizard TransformFireLizard TransformSnapper TransformRazor TransformBloodhound " +
            "TransformOrcDog TransformLurker TransformMinecrawler TransformHarpy TransformSwampshark " +
            "TransformShadowbeast");
        scrolls.bSorted = false;
        // Left out: test items, weapons only orcs and NPC casters carry, the copies used in story
        // scenes, blacksmith blanks and torches
        AddList("Melee weapons", "All melee weapons", "ItMw_", 1,
            "1H_Axe_01 1H_Axe_02 1H_Axe_03 1H_Axe_Bran 1H_Axe_Cord 1H_Axe_Hatchet_01 1H_Axe_Lares 1H_Axe_Old_01 " +
            "1H_Axe_Sickle_01 1H_Axe_Silas 1H_Mace_01 1H_Mace_02 1H_Mace_03 1H_Mace_04 1H_Mace_Club_01 " +
            "1H_Mace_Fortuno 1H_Mace_Lester 1H_Mace_Light_01 1H_Mace_Nailmace_01 1H_Mace_Namib 1H_Mace_Orun " +
            "1H_Mace_Poker_01 1H_Mace_Sledgehammer_01 1H_Mace_War_01 1H_Mace_War_02 1H_Mace_War_03 " +
            "1H_Mace_Warhammer_01 1H_Mace_Warhammer_02 1H_Mace_Warhammer_03 1H_Sword_01 1H_Sword_02 1H_Sword_03 " +
            "1H_Sword_04 1H_Sword_05 1H_Sword_05_Darrion 1H_Sword_Arto 1H_Sword_Bastard_01 1H_Sword_Bastard_02 " +
            "1H_Sword_Bastard_03 1H_Sword_Bastard_04 1H_Sword_Broad_01 1H_Sword_Broad_02 1H_Sword_Broad_03 " +
            "1H_Sword_Broad_04 1H_Sword_Kalom 1H_Sword_Lightguard_01 1H_Sword_Long_01 1H_Sword_Long_02 " +
            "1H_Sword_Long_03 1H_Sword_Long_04 1H_Sword_Long_05 1H_Sword_Old_01 1H_Sword_Old_02 1H_Sword_Paw " +
            "1H_Sword_Raven 1H_Sword_Scar 1H_Sword_Scythe_01 1H_Sword_Short_01 1H_Sword_Short_02 1H_Sword_Short_03 " +
            "1H_Sword_Short_04 1H_Sword_Short_05 1H_Sword_Whistler 2H_Axe_Gorn 2H_Axe_Heavy_01 2H_Axe_Heavy_02 " +
            "2H_Axe_Heavy_03 2H_Axe_Heavy_04 2H_Axe_Lee 2H_Axe_Light_01 2H_Axe_Light_02 2H_Axe_Light_03 " +
            "2H_Axe_Old_01 2H_Axe_Old_02 2H_Axe_Old_03 2H_Axe_Orc_01 2H_Axe_Orc_02 2H_Axe_Orc_03 2H_Axe_Orc_04 " +
            "2H_Axe_Orik 2H_Axe_Pickaxe 2H_Axe_Torlof 2H_Mace_Orc_01 2H_Staff_02 2H_Staff_Scepter 2H_Staff_Ulumulu " +
            "2H_Sword_01 2H_Sword_02 2H_Sword_03 2H_Sword_Beliar 2H_Sword_Heavy_01 2H_Sword_Heavy_02 " +
            "2H_Sword_Heavy_03 2H_Sword_Heavy_04 2H_Sword_Innos 2H_Sword_Light_01 2H_Sword_Light_02 " +
            "2H_Sword_Light_03 2H_Sword_Light_04 2H_Sword_Light_05 2H_Sword_Old_01 2H_Sword_Orc_01 2H_Sword_Thorus " +
            "2H_Sword_Uriziel_01 2H_Sword_Uriziel_02 2H_Sword_Uriziel_03 2H_Sword_Wind");
        AddList("Ranged weapons", "All ranged weapons", "ItRw_", 1,
            "Bow_Diego Bow_Long_01 Bow_Long_02 Bow_Long_03 Bow_Long_04 Bow_Long_05 Bow_Long_06 Bow_Long_07 " +
            "Bow_Long_08 Bow_Long_09 Bow_Long_10 Bow_Long_11 Bow_Long_12 Bow_Small_01 Bow_Small_02 Bow_Small_03 " +
            "Bow_Small_04 Bow_Small_05 Bow_War_01 Bow_War_02 Bow_War_03 Bow_War_04 Bow_War_05 Bow_Wolf " +
            "Crossbow_01 Crossbow_02 Crossbow_03 Crossbow_04");
        // the 23 armours the game gives a description
        AddList("Armours", "All armours", "", 1,
            "Vlk_Armor_L Vlk_Armor_M Stt_Armor Grd_Armor Ebr_Armor_M Ebr_Armor_H_01 Ebr_Armor_H_02 " +
            "Sfb_Armor_L Org_Armor Sld_Armor Ore_Armor_M Ore_Armor_H Kdw_Armor_L Kdw_Armor_H Kdf_Armor_L " +
            "Kdf_Armor_H Nov_Armor Tpl_Armor Gur_Armor_M Gur_Armor_H Dmb_Armor_M Crw_Armor_H Law_Armor");
        // the world map is what opens the map screen; some area maps belong to quests
        AddList("Maps", "All maps", "ItWr_Map_", 1,
            "World WorldComplete OldCamp NewCamp SwampCamp OldMine OldMineSC Orc Temple Cliff Lighthouse Focus");
        AddList("Animal trophies", "All animal trophies", "ItAt_", 5,
            "Biter_01 Biter_02 Biter_03 Bloodfly_01 Bloodfly_02 Bloodfly_03 Bloodhound_01 Bloodhound_02 " +
            "Crawler_01 Crawler_02 Crawlerqueen Damlurker_01 Firegolem_01 Firegolem_02 Firelizard_01 Firelizard_02 " +
            "Firelizard_03 Firelizard_04 Firelizard_05 Harpy_01 Harpy_02 Icegolem_01 Icegolem_02 Lizard_01 " +
            "Lizard_02 Lizard_03 Lurker_01 Lurker_02 Lurker_03 Meatbug_01 Minecrawlerqueen_01 Orcdog_01 Orcdog_02 " +
            "Razor_01 Razor_02 Scavenger_01 Scavenger_02 Shadow_01 Shadow_02 Shadow_03 Shadow_04 Shadow_05 " +
            "Shadow_06 Snapper_01 Snapper_02 Stonegolem_01 Stonegolem_02 Swampshark_01 Swampshark_02 Swampshark_03 " +
            "Swampshark_04 Teeth_01 Troll_01 Troll_02 Troll_03 Wolf_01 Wolf_02 Wolf_03");
        AddList("Smithing materials", "All smithing materials", "ItMi_Smith_", 10,
            "Iron Steel Gold Ironwood Oak Willow Petrifiedwood Leatherstraps Obsidian Ruby Swordraw");
        AddList("Alchemy ingredients", "All alchemy ingredients", "ItMi_", 10,
            "Alchemy_Flask Alchemy_Alcohol_01 Alchemy_Moleratlubric_01 Alchemy_Quicksilver_01 Alchemy_Salt_01 " +
            "Alchemy_Sulphur_01 Alchemy_Syranoil_01 Inscription_Parchment Plants_Swampherb_01 Joint_01 Joint_02 " +
            "Joint_03");
        AddList("Plants", "All plants", "ItFo_Plants_", 10,
            "Berrys_01 Bloodwood_01 Coral Darkshade Dewleaf Duskbell Flameberry_01 Herb_01 Herb_02 Herb_03 Lobelia " +
            "Mistcap Mountainmoss_01 Mountainmoss_02 Mushroom_01 Mushroom_02 Nightshadow_01 Nightshadow_02 " +
            "Orcherb_01 Orcherb_02 OrcSpore Ravenherb_01 Ravenherb_02 Seraphis_01 Siren Stoneroot_01 Stoneroot_02 " +
            "Trollbane Velayis_01 Widow");
        UCMItemListPage keys = AddList("Keys", "All keys", "ItKe_", 1,
            "AbandonedGallery_01 AbandonedMine_01 BanditCell Berg_01 CaptainShip Cavalorn_01 CellarCages_01 " +
            "Dungeonkey FireMagesRoom FiskStorage Focus_04 Focus_05 Freemine Gomez_01 GomezCastleMaster " +
            "GraveyardLever Kalom_01 LeeDoor LootCage_01 MerchantCellarDoor Om_02 Om_03 OrcGraveyard " +
            "OrcGraveyardPiece_01 OrcGraveyardPiece_02 Quentin_01 RavenTower Ricelord_01 Smith_01 Storage_01 " +
            "Sunkentower TavernDoor Tower_01");
        keys.bDistinct = true;
        // no "all" entry here: some quest items start or skip story steps when they turn up
        UCMItemListPage quest = AddList("Quest items", "", "", 1,
            "ItMs_Focus_01 ItMs_Focus_02 ItMs_Focus_03 ItMs_Focus_04 ItMs_Focus_05 ItMs_Uriziel ItMi_UrizielGem_01 " +
            "ItMi_UrizielGem_02 ItMi_UrizielGem_03 ItMi_UrizielGem_04 ItMi_UrizielGem_05 ItMs_SunkenTowerStone_01 " +
            "ItMs_SunkenTowerStone_02 ItMs_StoneSketch ItMs_Ashes ItMs_Axe_Bran ItMs_Book_Innos ItMs_Book_WaterMages " +
            "ItMs_Demonprank ItMs_DraxHunterKnife ItMs_ExplosionBarrel ItMs_ExplosionScroll ItMs_FakeDiggerClothes " +
            "ItMs_Lightbringer ItMs_Remedy ItMs_ScavengerWhistle ItMs_Spellblade ItMs_Timeblade ItMs_Winch " +
            "ItMs_Worldsplitter ItMi_Stuff_Gearwheel_01 ItMi_Stuff_Idolsleeper_01 ItMi_Specialjoint " +
            "ItMs_Scroll_AbandonedGuy ItMs_Scroll_InExtremo ItMs_Scroll_LoveInterest ItMs_Scroll_LoveInterest_2 " +
            "ItMs_Scroll_LoveStoryFogTower ItMs_Scroll_LoveStoryWomen ItMs_Scroll_OldRecipe ItMs_Scroll_PaintersCave " +
            "ItMs_Scroll_SerialKiller ItMs_Scroll_SyraRecipe ItMs_Scroll_ToyMaker ItMs_Scroll_WeaponDesign " +
            "ItMs_Scroll_WomensRevenge");
        quest.bDistinct = true;

        AddQuick("Ore x100", "ItMi_Orenugget", 100);
        AddQuick("Ore x1000", "ItMi_Orenugget", 1000);
        AddQuick("Lockpicks x10", "ItKe_Lockpick", 10);
        AddQuick("Healing potions x5", "ItFo_Potion_Health_03", 5);
        AddQuick("Mana potions x5", "ItFo_Potion_Mana_03", 5);
        AddQuick("Speed potions x3", "ItFo_Potion_Haste_03", 3);
        AddQuick("Arrows x50", "ItAm_Arrow", 50);
        AddQuick("Bolts x50", "ItAm_Bolt", 50);
        AddQuick("Torches x5", "ItMw_1H_Torch", 5);
        AddQuick("Strength elixir", "ItFo_Potion_Strength_03", 1);
        AddQuick("Dexterity elixir", "ItFo_Potion_Dex_03", 1);
        AddQuick("Elixir of life (max HP)", "ItFo_Potion_Health_Perma_03", 1);
        AddQuick("Elixir of spirit (max MP)", "ItFo_Potion_Mana_Perma_03", 1);
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (Lists.Num() == 0)
            Fill();
        for (UCMItemListPage page : Lists)
            Items.Add(CM::PageItem(page.Title, page));
        for (int i = 0; i < Quick.Num(); i++)
            Items.Add(CM::Item(Quick[i].Label, ECMKind::Action, FName("Quick" + i)));
    }

    FString Activate(FName Id, int Dir) override
    {
        FString s = Id.ToString();
        int i = String::Conv_StringToInt(s.RightChop(5));
        if (!s.StartsWith("Quick") || i < 0 || i >= Quick.Num())
            return "";
        return CMItems::Give(Quick[i]);
    }
}
