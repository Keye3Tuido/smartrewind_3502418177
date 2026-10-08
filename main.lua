local SmartRewind=RegisterMod('SmartRewind',1)
SmartRewind.Version='3.3.0'
local json=require('json')
local fontname=[[youyuan]]
local fontsize=.35

Isaac.ConsoleOutput('SmartRewind v'..SmartRewind.Version..' - Keye3Tuido\n')

-- Options.MaxScale = 99
-- Options.MaxRenderScale = 99
-- Options.MouseControl = true
-- Options.DebugConsoleEnabled = true
-- Options.SaveCommandHistory = true

local death=0
local autoRewindEnabled=true -- 新增：自动Rewind功能状态
local rewindUponPenalty=false -- 标记受惩罚伤害后是否自动后悔
local showMessage = false -- 用于显示消息的标志
local useRewind = true -- 使用Rewind替代发光沙漏

function SmartRewind:Save()
    local data={
        death=death,
        autoRewindEnabled=autoRewindEnabled, -- 保存功能状态
        rewindUponPenalty=rewindUponPenalty, -- 保存功能状态
        useRewind=useRewind -- 保存功能状态
    }
    self:SaveData(json.encode(data))
end

function SmartRewind:Load()
    if(self:HasData())then
        local data=json.decode(self:LoadData())
        if(type(data)=='table')then
            death=data.death or 0
            if data.autoRewindEnabled~=nil then
                autoRewindEnabled=data.autoRewindEnabled
            else
                autoRewindEnabled=true -- 如果没有保存状态，默认启用
            end
            if data.rewindUponPenalty~=nil then
                rewindUponPenalty=data.rewindUponPenalty
            else
                rewindUponPenalty=false -- 如果没有保存状态，默认禁用
            end
            if data.useRewind~=nil then
                useRewind=data.useRewind
            else
                useRewind=true -- 如果没有保存状态，默认启用
            end
            return
        end
    end
    death=0
    autoRewindEnabled=true -- 默认启用
    rewindUponPenalty=false -- 默认禁用
    useRewind=true -- 默认启用
end
local PlayerHasDogma = {}
SmartRewind:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,function(self,isContinued)
    PlayerHasDogma = {}
    self:Load()
    if not isContinued then
        death = 0
        self:Save()
    end
end)
SmartRewind:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,function(self,shouldSave)
    death = shouldSave and death or 0
    self:Save()
end)
--------------------------------------------------------------------------------
local BeastRoom=false
SmartRewind:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,function()
    if(Game():GetLevel():GetCurrentRoomDesc().Data.Name=='Beast Room')then
        if(not BeastRoom)then
            for i=1, Game():GetNumPlayers() do
                local player = Isaac.GetPlayer(i-1)
                local hash = GetPtrHash(player)
                if not PlayerHasDogma[hash] then
                    player:RemoveCollectible(CollectibleType.COLLECTIBLE_DOGMA)
                end
            end
            Isaac.ExecuteCommand('goto x.itemdungeon.666')
            BeastRoom=true
        end
    else
        BeastRoom=false
    end
    for i=1, Game():GetNumPlayers() do
        local player = Isaac.GetPlayer(i-1)
        local hash = GetPtrHash(player)
        PlayerHasDogma[hash] = player:HasCollectible(CollectibleType.COLLECTIBLE_DOGMA)
    end
end)
--------------------------------------------------------------------------------
local useflag=UseFlag.USE_NOANIM|UseFlag.USE_NOCOSTUME|UseFlag.USE_ALLOWNONMAIN|UseFlag.USE_NOANNOUNCER|UseFlag.USE_CUSTOMVARDATA|UseFlag.USE_NOHUD
local reviveFrame=0
SmartRewind:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,function(self,player) -- 死亡自动后悔
    if autoRewindEnabled and not rewindUponPenalty and (not player.Parent and player:IsDead() and not player:WillPlayerRevive())then
        player:Revive()
        player:UseActiveItem(CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS,useflag)
        local currentFrame=Isaac.GetFrameCount()
        if(currentFrame>reviveFrame and useRewind)then
            reviveFrame=currentFrame
            Isaac.ExecuteCommand('rewind')
        end
        death=death+1
        self:Save()
    end
end)
SmartRewind:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,function(self,entity,_,flags,source)    --惩罚自动后悔
    local player=entity:ToPlayer()
    if autoRewindEnabled and rewindUponPenalty and player and not player.Parent then
        if (DamageFlag.DAMAGE_RED_HEARTS|DamageFlag.DAMAGE_IV_BAG|DamageFlag.DAMAGE_FAKE|DamageFlag.DAMAGE_NO_PENALTIES)&flags>0 or player:GetPlayerType()==PlayerType.PLAYER_JACOB_B and source.Type==EntityType.ENTITY_DARK_ESAU then
            return
        end
        if useRewind then
            Isaac.ExecuteCommand('rewind')
        else
            player:UseActiveItem(CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS,useflag)
        end
        death=death+1
        self:Save()
        return false
    end
end,EntityType.ENTITY_PLAYER)
--------------------------------------------------------------------------------
local anm2Filename='gfx/005.100_Collectible.anm2'
local gfxFilename=Isaac.GetItemConfig():GetCollectible(CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS).GfxFileName
local sprite=Sprite()
sprite:Load(anm2Filename,true)
sprite:ReplaceSpritesheet(1,gfxFilename)
sprite:LoadGraphics()
sprite:SetFrame('Idle',1)
sprite.Scale=Vector(0.3,0.3)

local gfxFilename2=Isaac.GetItemConfig():GetCollectible(CollectibleType.COLLECTIBLE_CROWN_OF_LIGHT).GfxFileName
local sprite2=Sprite()
sprite2:Load(anm2Filename,true)
sprite2:ReplaceSpritesheet(1,gfxFilename2)
sprite2:LoadGraphics()
sprite2:SetFrame('Idle',1)
sprite2.Scale=Vector(0.3,0.3)

local posX, posY = 5, Isaac.GetScreenHeight()
local dragging = false
local dragOffsetX, dragOffsetY = 0, 0
local lastMouseLeftPressed = false -- 跟踪左键状态
local lastMouseRightPressed = false -- 跟踪右键状态

SmartRewind:AddCallback(ModCallbacks.MC_POST_RENDER,function(self)
    if not Options.MouseControl then
        local pos = Isaac.WorldToScreen(Input.GetMousePosition(true))
        Isaac.RenderText('o',pos.X-2.2,pos.Y-6.4,0,1,1,1)
    end
    self:Load()
    local mousePos = Isaac.WorldToScreen(Input.GetMousePosition(true))
    local mouseX, mouseY = mousePos.X, mousePos.Y
    local mouseLeftPressed = Input.IsMouseBtnPressed(Mouse.MOUSE_BUTTON_LEFT) -- 左键状态
    local mouseRightPressed = Input.IsMouseBtnPressed(Mouse.MOUSE_BUTTON_RIGHT)
    local mouseMiddlePressed = Input.IsMouseBtnPressed(Mouse.MOUSE_BUTTON_MIDDLE)
    
    local textWidth = #tostring(death) * 2
    local iconWidth = textWidth + 8
    local iconHeight = 12
    local iconArea = {
        left = posX - 4,
        right = posX + iconWidth,
        top = posY - iconHeight,
        bottom = posY
    }
    
    -- 检测鼠标是否在图标区域内
    local mouseInIcon = (mouseX >= iconArea.left and mouseX <= iconArea.right and
                       mouseY >= iconArea.top and mouseY <= iconArea.bottom)
    
    -- 中键拖动处理
    if not dragging and mouseMiddlePressed then
        if mouseInIcon then
            dragging = true
            dragOffsetX = mouseX - posX
            dragOffsetY = mouseY - posY
        end
    elseif dragging then
        if mouseMiddlePressed then
            posX = mouseX - dragOffsetX
            posY = mouseY - dragOffsetY
        else
            dragging = false
        end
    end
    
    -- 左键点击切换功能状态
    if mouseInIcon then
        -- 左键点击检测（按下后释放）
        if lastMouseLeftPressed and not mouseLeftPressed then
            if autoRewindEnabled then
                if rewindUponPenalty then   -- 关闭自动后悔
                    autoRewindEnabled = false
                    rewindUponPenalty = false
                else    -- 受到惩罚伤害自动后悔
                    rewindUponPenalty = true
                end
            else    -- 死亡时自动后悔
                autoRewindEnabled = true
                rewindUponPenalty = false
            end
            self:Save()
            showMessage = true
        end
        if lastMouseRightPressed and not mouseRightPressed then
            useRewind = not useRewind
            self:Save()
            showMessage = true
        end

    end
    lastMouseLeftPressed = mouseLeftPressed
    lastMouseRightPressed = mouseRightPressed
    
    -- 限制图标位置在屏幕内
    posX = math.max(4, math.min(Isaac.GetScreenWidth() - iconWidth - 4, posX))
    posY = math.max(iconHeight, math.min(Isaac.GetScreenHeight(), posY))
    local iconPos = Vector(posX, posY)
    
    -- 根据功能状态设置颜色
    if autoRewindEnabled then
        if rewindUponPenalty then
            sprite2.Color = Color(1, 1, 1, 1)
            if not Game():GetHUD():IsVisible() then return end
            sprite2:Render(iconPos) -- 受到惩罚伤害后自动后悔
        else
            sprite.Color = Color(1, 1, 1, 1) -- 白色：功能启用
            if not Game():GetHUD():IsVisible() then return end
            sprite:Render(iconPos) -- 死亡时自动后悔
        end
    else
        sprite.Color = Color(0.3, 0.3, 0.3, 1) -- 灰色：功能禁用
        if not Game():GetHUD():IsVisible() then return end
        sprite:Render(iconPos)
    end
    
    -- 文字颜色与图标一致
    local textColor = autoRewindEnabled and {0,1,1,1} or {0.3,0.3,0.3,1}
    Isaac.RenderScaledText(death, iconPos.X + 3, iconPos.Y - 9.5, 0.5, 0.5, table.unpack(textColor))
end)

local beginTime = 0
local font = Font()
font:Load(require('debug').getinfo(1,'S').source:match("^@(.*)main%.lua$")..'font/'..fontname:match('^%s*(%S+)%s*$')..'.fnt')
-- font:Load('font/teammeatex/teammeatex10.fnt')
-- font:Load('font/cjk/lanapixel.fnt')
local function MsgLen(msg)
    local len=0
    for _,v in ipairs(msg) do
        len=len+font:GetStringWidthUTF8(v)
    end
    return len
end
local function DrawMessage(str,x,y,kc,sz)
    sz = sz or fontsize
    local len=font:GetStringWidthUTF8(str)
    font:DrawStringScaledUTF8(str,x,y,sz,sz,kc,math.floor(sz*len+.5),true)
    return x+sz*len
end
SmartRewind:AddCallback(ModCallbacks.MC_POST_RENDER,function()
    if showMessage then
        beginTime=Isaac.GetTime()
        showMessage = false
    end
    local time = Isaac.GetTime() - beginTime
    local duration = 5e3
    if  time <= duration then
        local center=Vector(Isaac.GetScreenWidth()/2, Isaac.GetScreenHeight()/2)
        local messageCN,messageEN={},{}
        local helpCN1,helpCN2,helpEN1,helpEN2,helpEN3={},{},{},{},{}
        local alpha=(duration - time)/1e3
        local kcolor0=KColor.White
        kcolor0.Alpha = alpha
        local kcolor1,kcolor2
        if autoRewindEnabled then
            if rewindUponPenalty then
                messageCN={'无瑕模式',' : 主角色受到',' 惩罚伤害 ','时自动后悔'}
                messageEN={'Faultless Mode',' : Main Players rewinds upon',' PENALTY DAMAGE ','automatically'}
                kcolor1,kcolor2=KColor.Cyan,KColor.Magenta
            else
                messageCN={'复生模式',' : 主角色受到',' 致命伤害 ','时自动后悔'}
                messageEN={'Revival Mode',' : Main Players rewinds upon',' FATAL DAMAGE ','automatically'}
                kcolor1,kcolor2=KColor.Green,KColor.Red
            end
        else
            messageCN={'','自动后悔',' 已禁用'}
            messageEN={'','Auto-Rewind',' DISABLED'}
            kcolor1,kcolor2=kcolor0,KColor.Red
        end
        kcolor1.Alpha, kcolor2.Alpha = alpha, alpha
        local msgs={messageCN,messageEN}
        local kcolors={kcolor1,kcolor0,kcolor2,kcolor0}
        for i,msg in ipairs(msgs)do
            local x=center.X-fontsize*MsgLen(msg)/2
            local y=center.Y+(i-3)*fontsize*font:GetBaselineHeight()
            for j,str in ipairs(msg)do
                x=DrawMessage(str,x,y,kcolors[j])
            end
        end
        if useRewind and autoRewindEnabled then
            helpCN1={'当前后悔操作 : 使用发光沙漏，',' 并在下一帧使用 rewind 指令','(更精准)，'}
            helpCN2={'','','若要禁用指令，请',' 右键点击图标'}
            helpEN1={'Current Rewind Action : Use Glowing Hourglass, and',}
            helpEN2={'',' use REWIND COMMAND in the next frame','(more precise),'}
            helpEN3={'','','to disable the command, please',' Right-Click the icon'}
            kcolor1,kcolor2=KColor.Green,KColor.Cyan
        elseif autoRewindEnabled then
            helpCN1={'当前后悔操作 : ',' 仅使用发光沙漏','(更兼容)，'}
            helpCN2={'','','若要启用指令，请',' 右键点击图标'}
            helpEN1={'Current Rewind Action :',' ONLY use Glowing Hourglass','(more compatible),'}
            helpEN2={'','','to enable the command, please ',' Right-Click the icon'}
            helpEN3={''}
            kcolor1,kcolor2=KColor.Cyan,KColor.Green
        end
        kcolor1.Alpha, kcolor2.Alpha = alpha, alpha
        local helps={helpCN1,helpCN2,helpEN1,helpEN2,helpEN3}
        kcolors={kcolor0,kcolor1,kcolor0,kcolor2}
        local helpsize = .8*fontsize
        for i,help in ipairs(helps)do
            local x=center.X-helpsize*MsgLen(help)/2
            local y=center.Y+i*helpsize*font:GetBaselineHeight()
            for j,str in ipairs(help)do
                x=DrawMessage(str,x,y,kcolors[j],helpsize)
            end
        end
    end

end)
---------------------------------------------------------------------------------