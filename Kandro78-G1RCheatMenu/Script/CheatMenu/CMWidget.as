// G1R Cheat Menu: the menu panel. A script widget without a widget blueprint, painted in OnPaint.
// The look follows the game's menus like the UE4SS versions: the grunge backdrop of the game's
// tooltips, a centred pale salmon block-letter title over the game's title ornament, serif rows in
// warm off-white with copper values, the selected row as a pale salmon plate with dark text. Fonts
// and textures are the game's own, loaded at runtime.

class UCMWidget : UUserWidget
{
    UPROPERTY()
    UFont BodyFont;
    UPROPERTY()
    UFont TitleFont;
    UPROPERTY()
    USlateBrushAsset Backdrop;
    UPROPERTY()
    USlateBrushAsset TitleLine;
    UPROPERTY()
    USlateBrushAsset ItemSlot;
    const float LineW = 300; // the ornament's native size; other sizes distort it
    const float LineH = 24;

    // filled by the menu before every repaint
    FString Title;
    FString Path; // the pages above this one
    TArray<FString> Labels;
    TArray<FString> Values;
    TArray<bool> IsPage;
    int Selected = 0;
    int First = 0; // first visible row
    FString Hint;
    FString Status;

    // layout in slate units (the engine scales them with the screen's DPI)
    int VisibleRows = 14;
    float Left = 60;
    float Top = 100;
    float Pad = 26;
    float RowH = 34;
    float BodySize = 16;
    float TitleSize = 30;
    float PathTop = 12;
    float TitleTop = 26;
    float RuleTop = 72;
    float ListTop = 104;
    const float MinWidth = 520;
    const float MaxWidth = 900;
    const float MinValueX = 344; // where the values start in the narrowest panel

    // set by Layout from the texts: translations run longer than the English ones
    float Width = 520;
    float ValueX = 344; // from the panel's left edge

    void LoadFonts()
    {
        if (BodyFont == nullptr)
            BodyFont = FAssetPreload::BlockingLoad(TSoftObjectPtr<UFont>(n"/Game/UI/Fonts/NotoSerif-Regular_Font.NotoSerif-Regular_Font"));
        if (TitleFont == nullptr)
            TitleFont = FAssetPreload::BlockingLoad(TSoftObjectPtr<UFont>(n"/Game/UI/Fonts/Boucherie-Block_Font.Boucherie-Block_Font"));
        if (Backdrop == nullptr)
            Backdrop = Brush(n"/Game/UI/Textures/Common/T_GrungeTooltipBackground_Wide.T_GrungeTooltipBackground_Wide");
        if (TitleLine == nullptr)
            TitleLine = Brush(n"/Game/UI/Textures/ManagementUI/Inventory/T_TooltipTitleLine.T_TooltipTitleLine");
        if (ItemSlot == nullptr)
            ItemSlot = Brush(n"/Game/UI/Textures/ManagementUI/Inventory/T_InventorySlot_Default.T_InventorySlot_Default");
    }

    // a brush for one of the game's textures; nullptr when a game update moved it (the menu then
    // draws a flat backdrop and a plain line)
    USlateBrushAsset Brush(FName AssetPath)
    {
        UTexture2D texture = FAssetPreload::BlockingLoad(TSoftObjectPtr<UTexture2D>(AssetPath));
        if (texture == nullptr)
            return nullptr;
        USlateBrushAsset brush = Cast<USlateBrushAsset>(NewObject(this, USlateBrushAsset));
        brush.Brush = Widget::MakeBrushFromTexture(texture);
        return brush;
    }

    // a widget cannot measure text while painting, so widths are estimated from the length; this
    // share of the font size per character fits the game's serif font with a little to spare
    // (Chinese and Japanese characters take a full square)
    float TextWidth(FString S, float Size) const
    {
        return S.Len() * Size * (CM::WideScript() ? 1.0 : 0.56);
    }

    // the value column starts after the longest label that has a value next to it, and the panel
    // is as wide as its longest line needs
    void Layout()
    {
        float labels = 0;
        float values = 0;
        float lines = 0;
        for (int i = 0; i < Labels.Num(); i++)
        {
            float label = TextWidth(Labels[i], BodySize);
            lines = Math::Max(lines, Pad + label);
            if (Values[i] != "" || IsPage[i])
                labels = Math::Max(labels, label);
            values = Math::Max(values, TextWidth(Values[i], BodySize));
        }
        ValueX = Math::Max(MinValueX, Pad + labels + 24);
        float width = Math::Max(MinWidth, ValueX + Math::Max(values, 20) + Pad);
        width = Math::Max(width, lines + Pad);
        // small text runs wider for its size, Cyrillic most of all
        width = Math::Max(width, 2 * Pad + TextWidth(Hint, 12) * 1.2);
        width = Math::Max(width, 2 * Pad + TextWidth(Status, 13) * 1.2);
        width = Math::Max(width, 2 * Pad + TextWidth(Title, TitleSize * 0.9) + 90);
        Width = Math::Min(width, MaxWidth);
        ValueX = Math::Min(ValueX, Width - Pad - Math::Max(values, 20));
    }

    // the selected item, shown in a second panel styled like the game's item tooltip
    TSubclassOf<UItemDefinition> Item;
    TSubclassOf<UItemDefinition> WornItem; // the equipped item it is compared with
    UPROPERTY()
    UTexture2D Icon;
    UPROPERTY()
    USlateBrushAsset IconBrush;
    FString ItemName;
    FString ItemKind;
    FString Equipped;
    FString Description;
    TArray<FCMItemStat> Stats;
    const float InfoWidth = 340;

    void SetItem(TSubclassOf<UItemDefinition> ItemClass)
    {
        TSubclassOf<UItemDefinition> worn;
        if (ItemClass.IsValid())
            worn = CMItems::Worn(ItemClass);
        if (ItemClass == Item && worn == WornItem)
            return;
        Item = ItemClass;
        WornItem = worn;
        Description = "";
        Equipped = "";
        Stats.Reset();
        Icon = nullptr;
        if (!ItemClass.IsValid())
            return;
        ItemName = CMItems::Name(ItemClass);
        ItemKind = CMItems::Kind(ItemClass);
        Description = CMItems::Description(ItemClass);
        Stats = CMItems::Stats(ItemClass, worn);
        if (worn.IsValid())
            Equipped = CM::F("Equipped: {0}", CMItems::Name(worn));
        Icon = CMItems::Icon(ItemClass);
        if (Icon == nullptr)
            return;
        if (IconBrush == nullptr)
            IconBrush = Cast<USlateBrushAsset>(NewObject(this, USlateBrushAsset));
        IconBrush.Brush = Widget::MakeBrushFromTexture(Icon, 128, 128);
    }

    // splits S into lines that fit Limit, at spaces
    TArray<FString> Wrap(FString S, float Size, float Limit) const
    {
        TArray<FString> words;
        S.ParseIntoArray(words, " ", true);
        TArray<FString> lines;
        FString line = "";
        for (FString word : words)
        {
            FString longer = line == "" ? word : line + " " + word;
            if (line != "" && TextWidth(longer, Size) > Limit)
            {
                lines.Add(line);
                line = word;
            }
            else
                line = longer;
        }
        if (line != "")
            lines.Add(line);
        return lines;
    }

    void Repaint()
    {
        InvalidateLayoutAndVolatility();
    }

    // a filled rectangle: one thick line through its middle. The thickness is in screen pixels, not
    // in slate units like the positions, so it is scaled by the viewport's DPI scale.
    void Fill(FPaintContext& Context, float L, float T, float W, float H, FLinearColor Color) const
    {
        float scale = WidgetLayout::GetViewportScale();
        Widget::DrawLine(Context, FVector2D(L, T + H * 0.5), FVector2D(L + W, T + H * 0.5), Color, false, H * Math::Max(scale, 1.0));
    }

    // the backdrop of the game's tooltips (sharper than its grunge background, which blurs at this
    // size); a flat one when it is missing
    void Backplate(FPaintContext& Context, float L, float T, float W, float H) const
    {
        if (Backdrop != nullptr)
            Widget::DrawBox(Context, FVector2D(L, T), FVector2D(W, H), Backdrop, CM::Srgb(255, 255, 255, 0.95));
        else
            Fill(Context, L, T, W, H, CM::Srgb(10, 10, 10, 0.92));
    }

    // the game's title ornament centred on X
    void Ornament(FPaintContext& Context, float X, float T, FLinearColor Color) const
    {
        if (TitleLine != nullptr)
            Widget::DrawBox(Context, FVector2D(X - LineW * 0.5, T), FVector2D(LineW, LineH), TitleLine, Color);
        else
            Fill(Context, X - LineW * 0.5, T + LineH * 0.5, LineW, 1, Color);
    }

    void Text(FPaintContext& Context, FString S, float L, float T, UFont Font, float Size, FLinearColor Color, FName Typeface = NAME_None) const
    {
        Widget::DrawTextFormatted(Context, FText::FromString(S), FVector2D(L, T), Font, Size, Typeface, Color);
    }

    // S centred on X / ending at X, by the estimated width
    void Centred(FPaintContext& Context, FString S, float X, float T, UFont Font, float Size, FLinearColor Color) const
    {
        Text(Context, S, X - TextWidth(S, Size) * 0.5, T, Font, Size, Color);
    }

    void RightAligned(FPaintContext& Context, FString S, float X, float T, float Size, FLinearColor Color) const
    {
        Text(Context, S, X - TextWidth(S, Size), T, BodyFont, Size, Color);
    }

    UFUNCTION(BlueprintOverride)
    void OnPaint(FPaintContext& Context) const
    {
        const FLinearColor titleColor = CM::Srgb(243, 214, 203);
        const FLinearColor textColor = CM::Srgb(244, 226, 217);
        const FLinearColor valueColor = CM::Srgb(205, 160, 133);
        const FLinearColor muted = CM::Srgb(135, 134, 134);
        const FLinearColor hairline = CM::Srgb(87, 87, 87);
        const FLinearColor plate = CM::Srgb(250, 223, 207);
        const FLinearColor plateText = CM::Srgb(14, 12, 11);

        const int shown = Math::Min(VisibleRows, Labels.Num());
        const float listBottom = Top + ListTop + Math::Max(shown, 1) * RowH;
        const float footTop = listBottom + 12;
        const float height = footTop + 52 - Top;

        Backplate(Context, Left, Top, Width, height);

        Text(Context, Path, Left + Pad, Top + PathTop, BodyFont, 12, muted);
        Text(Context, Title, Left + (Width - TextWidth(Title, TitleSize * 0.9)) * 0.5, Top + TitleTop, TitleFont, TitleSize, titleColor);
        // where the selection is in a list longer than the panel
        if (Labels.Num() > VisibleRows)
        {
            FString counter = "" + (Selected + 1) + " / " + Labels.Num();
            Text(Context, counter, Left + Width - Pad - TextWidth(counter, 13), Top + TitleTop + 14, BodyFont, 13, muted);
        }
        Ornament(Context, Left + Width * 0.5, Top + RuleTop, titleColor);

        for (int row = 0; row < shown; row++)
        {
            const int i = First + row;
            if (i >= Labels.Num())
                break;
            const float y = Top + ListTop + row * RowH;
            FLinearColor labelColor = textColor;
            FLinearColor rightColor = valueColor;
            if (i == Selected)
            {
                Fill(Context, Left + Pad - 10, y, Width - 2 * Pad + 20, RowH, plate);
                labelColor = plateText;
                rightColor = plateText;
            }
            Text(Context, Labels[i], Left + Pad, y + 5, BodyFont, BodySize, labelColor);
            FString right = Values[i];
            if (right == "" && IsPage[i])
                right = ">";
            if (right != "")
                Text(Context, right, Left + ValueX, y + 5, BodyFont, BodySize, rightColor);
        }

        // more rows above / below than fit
        if (First > 0)
            Text(Context, "...", Left + Width - Pad - 20, Top + ListTop - 22, BodyFont, BodySize, muted);
        if (First + shown < Labels.Num())
            Text(Context, "...", Left + Width - Pad - 20, listBottom - RowH + 5, BodyFont, BodySize, muted);

        Fill(Context, Left + Pad, listBottom + 4, Width - 2 * Pad, 1, hairline);
        Text(Context, Status, Left + Pad, footTop, BodyFont, 13, valueColor);
        Text(Context, Hint, Left + Pad, footTop + 22, BodyFont, 12, muted);

        if (!Item.IsValid())
            return;
        // the item panel, laid out like the game's tooltip: icon, name in the title font, kind, the
        // stats as rows on a darker band, the description in italics on a lighter one
        const FLinearColor band = CM::Srgb(0, 0, 0, 0.45);
        const FLinearColor descriptionBand = CM::Srgb(48, 46, 44, 0.55);
        const FLinearColor better = CM::Srgb(126, 196, 112);
        const FLinearColor worse = CM::Srgb(214, 96, 84);
        const float x = Left + Width + 12;
        const float centre = x + InfoWidth * 0.5;
        const float textWidth = InfoWidth - 2 * Pad;
        const float nameSize = 22;
        TArray<FString> nameLines = Wrap(ItemName, nameSize, textWidth);
        TArray<FString> descriptionLines = Wrap(Description, 14, textWidth);
        const float iconSize = Icon != nullptr ? 112 : 0; // the inventory slot; the icon sits inside it
        const float rowH = 26;
        const float lineH = 20;

        // heights first: the backdrop goes under everything
        float headH = Pad + (Icon != nullptr ? iconSize + 10 : 0) + nameLines.Num() * 30;
        if (ItemKind != "")
            headH += 22;
        if (Equipped != "")
            headH += 20;
        headH += LineH + 12;
        const float statsH = Stats.Num() > 0 ? Stats.Num() * rowH + 12 : 0;
        const float descriptionH = descriptionLines.Num() > 0 ? descriptionLines.Num() * lineH + 18 : 0;
        Backplate(Context, x, Top, InfoWidth, headH + statsH + descriptionH + Pad * 0.5);

        float y = Top + Pad;
        if (Icon != nullptr)
        {
            if (ItemSlot != nullptr)
                Widget::DrawBox(Context, FVector2D(centre - iconSize * 0.5, y), FVector2D(iconSize, iconSize), ItemSlot);
            const float inset = ItemSlot != nullptr ? 10 : 0;
            Widget::DrawBox(Context, FVector2D(centre - iconSize * 0.5 + inset, y + inset), FVector2D(iconSize - 2 * inset, iconSize - 2 * inset), IconBrush);
            y += iconSize + 10;
        }
        for (FString line : nameLines)
        {
            Centred(Context, line, centre, y, TitleFont, nameSize, titleColor);
            y += 30;
        }
        if (ItemKind != "")
        {
            Centred(Context, ItemKind, centre, y, BodyFont, 14, muted);
            y += 22;
        }
        if (Equipped != "")
        {
            Centred(Context, Equipped, centre, y, BodyFont, 12, muted);
            y += 20;
        }
        Ornament(Context, centre, y + 6, titleColor);
        y += LineH + 12;

        if (Stats.Num() > 0)
        {
            Fill(Context, x, y, InfoWidth, statsH, band);
            y += 6;
            for (FCMItemStat stat : Stats)
            {
                Text(Context, "+", x + Pad, y + 3, BodyFont, 15, valueColor);
                Text(Context, stat.Name, x + Pad + 16, y + 3, BodyFont, 15, textColor);
                RightAligned(Context, stat.Value, x + InfoWidth - Pad, y + 3, 15, titleColor);
                if (stat.bCompare)
                {
                    FString difference = Math::Abs(stat.Difference) < 0.01 ? "=" : (stat.Difference > 0 ? "+" : "") + CM::Num(stat.Difference);
                    FLinearColor color = Math::Abs(stat.Difference) < 0.01 ? muted : (stat.Difference > 0 ? better : worse);
                    RightAligned(Context, difference, x + InfoWidth - Pad - 52, y + 4, 13, color);
                }
                y += rowH;
            }
            y += 6;
        }

        if (descriptionLines.Num() > 0)
        {
            Fill(Context, x, y, InfoWidth, descriptionH, descriptionBand);
            y += 9;
            // the game's serif font has an italic face; without it Slate falls back to the regular one
            for (FString line : descriptionLines)
            {
                Text(Context, line, x + Pad, y, BodyFont, 14, CM::Srgb(170, 165, 160), n"Italic");
                y += lineH;
            }
        }
    }
}
