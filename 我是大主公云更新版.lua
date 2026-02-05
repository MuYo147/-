-- ==================== 云更新模块开始 ====================
-- 配置区（用户需要修改这里）
local CONFIG = {
    VERSION = "1.1.0", -- 当前脚本版本，每次更新必须增大此值
    UPDATE_URL = "https://raw.githubusercontent.com/你的用户名/你的仓库名/main/我是大主公云更新版.lua", -- 新版本脚本的直链
    CHECK_INTERVAL = 1, -- 更新检查间隔（小时），默认1小时检查一次
    ENABLE_UPDATE = true -- 是否启用云更新功能
}

-- 内部状态，无需修改
local updateData = {
    lastCheckTime = 0,
    notifiedUpdate = false
}

-- 网络请求函数（支持更多链接格式）
function HttpGet(url)
    local status, result = pcall(function()
        if gg and gg.makeRequest then
            -- 方式1：使用GG内置函数（如果可用）
            local headers = {
                "User-Agent: Mozilla/5.0 (Android; Mobile)"
            }
            return gg.makeRequest(url, headers).content
        else
            -- 方式2：尝试使用系统函数
            return gg.httpGet(url)
        end
    end)
    
    if status and result and result ~= "" then
        return result
    else
        -- 方式3：备用方案，处理常见平台链接
        if url:find("githubusercontent") then
            -- 如果是GitHub Raw链接，尝试添加备用访问方式
            local altUrl = url:gsub("raw%.githubusercontent", "raw")
            local altResult = gg.httpGet(altUrl)
            if altResult and altResult ~= "" then
                return altResult
            end
        end
        return nil
    end
end

-- 解析版本号
function ParseVersion(versionStr)
    if not versionStr then return nil end
    local major, minor, patch = versionStr:match("(%d+)%.(%d+)%.(%d+)")
    if major then
        return tonumber(major), tonumber(minor), tonumber(patch)
    end
    return nil
end

-- 比较版本号
function CompareVersion(v1, v2)
    local m1, mi1, p1 = ParseVersion(v1)
    local m2, mi2, p2 = ParseVersion(v2)
    
    if not m1 or not m2 then return 0 end
    
    if m1 > m2 then return 1
    elseif m1 < m2 then return -1
    elseif mi1 > mi2 then return 1
    elseif mi1 < mi2 then return -1
    elseif p1 > p2 then return 1
    elseif p1 < p2 then return -1
    else return 0 end
end

-- 从脚本内容中提取版本号
function ExtractVersionFromScript(scriptContent)
    if not scriptContent then return nil end
    
    -- 匹配 VERSION = "x.x.x" 格式
    local version = scriptContent:match('VERSION%s*=%s*["\'](%d+%.%d+%.%d+)["\']')
    
    -- 如果没找到，尝试匹配其他常见格式
    if not version then
        version = scriptContent:match('version%s*=%s*["\'](%d+%.%d+%.%d+)["\']')
    end
    
    return version
end

-- 检查更新
function CheckForUpdate()
    if not CONFIG.ENABLE_UPDATE then
        return false
    end
    
    local currentTime = os.time()
    -- 检查是否到达检查间隔
    if currentTime - updateData.lastCheckTime < CONFIG.CHECK_INTERVAL * 3600 then
        return false
    end
    
    updateData.lastCheckTime = currentTime
    gg.toast("正在检查更新...")
    
    -- 获取远程脚本
    local remoteScript = HttpGet(CONFIG.UPDATE_URL)
    if not remoteScript then
        gg.toast("更新检查失败，无法连接服务器")
        return false
    end
    
    -- 提取远程版本号
    local remoteVersion = ExtractVersionFromScript(remoteScript)
    if not remoteVersion then
        gg.toast("更新检查失败，无效的脚本格式")
        return false
    end
    
    -- 比较版本
    local comparison = CompareVersion(remoteVersion, CONFIG.VERSION)
    
    if comparison > 0 then
        -- 有新版本
        gg.toast("发现新版本 v" .. remoteVersion)
        
        -- 弹出更新提示
        local updateChoice = gg.choice({
            "立即更新到 v" .. remoteVersion,
            "本次忽略",
            "不再提示"
        }, nil, "发现新版本 v" .. remoteVersion .. "\n当前版本 v" .. CONFIG.VERSION)
        
        if updateChoice == 1 then
            return PerformUpdate(remoteScript, remoteVersion)
        elseif updateChoice == 2 then
            gg.toast("已忽略本次更新")
            return false
        elseif updateChoice == 3 then
            CONFIG.ENABLE_UPDATE = false
            gg.toast("已关闭自动更新")
            return false
        end
    else
        gg.toast("当前已是最新版本 v" .. CONFIG.VERSION)
        return false
    end
end

-- 执行更新
function PerformUpdate(newScript, newVersion)
    gg.toast("正在下载更新...")
    
    -- 生成临时文件名
    local tempFile = gg.EXT_STORAGE .. "/我是大主公一键启动_temp.lua"
    
    -- 写入新脚本
    local file, err = io.open(tempFile, "w")
    if not file then
        gg.alert("更新失败：无法创建临时文件\n" .. (err or ""))
        return false
    end
    
    file:write(newScript)
    file:close()
    
    -- 验证文件
    local verifyFile = io.open(tempFile, "r")
    if not verifyFile then
        gg.alert("更新失败：文件验证错误")
        return false
    end
    
    local firstLine = verifyFile:read()
    verifyFile:close()
    
    if not firstLine or not firstLine:find("function") then
        gg.alert("更新失败：文件内容无效")
        os.remove(tempFile)
        return false
    end
    
    -- 更新成功，提示用户
    gg.alert("更新下载完成！\n\n新版本: v" .. newVersion .. "\n\n请手动重启脚本以应用更新。\n\n临时文件位置:\n" .. tempFile)
    
    -- 提供重启选项
    local restartChoice = gg.choice({
        "知道了，稍后重启",
        "立即重启脚本（实验性）"
    }, nil, "更新下载完成")
    
    if restartChoice == 2 then
        -- 尝试重启脚本
        gg.toast("正在重启脚本...")
        loadfile(tempFile)()
    end
    
    return true
end

-- 手动检查更新（添加到菜单）
function ManualCheckUpdate()
    CONFIG.ENABLE_UPDATE = true
    updateData.lastCheckTime = 0
    gg.toast("正在手动检查更新...")
    
    -- 强制立即检查
    local currentTime = os.time()
    updateData.lastCheckTime = currentTime - CONFIG.CHECK_INTERVAL * 3600 - 1
    
    CheckForUpdate()
end

-- 初始化更新模块
function InitUpdateModule()
    if CONFIG.ENABLE_UPDATE then
        -- 每秒检查一次是否需要检查更新
        local initCheckDone = false
        local initCheckTime = os.time()
        
        while not initCheckDone do
            local currentTime = os.time()
            if currentTime - initCheckTime > 5 then
                -- 等待5秒后检查更新
                CheckForUpdate()
                initCheckDone = true
            end
            gg.sleep(1000)
        end
    end
end

-- ==================== 云更新模块结束 =================


function split(szFullString, szSeparator) 
local nFindStartIndex = 1 
local nSplitIndex = 1 
local nSplitArray = {} 
while true do 
local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex) 
if not nFindLastIndex then 
nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString)) 
break end 
nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1) 
nFindStartIndex = nFindLastIndex + string.len(szSeparator) 
nSplitIndex = nSplitIndex + 1 end return 
nSplitArray end 

function xgxc(szpy, qmxg) 
local xgsl = 0  -- 添加局部变量初始化
for x = 1, #(qmxg) do 
xgpy = szpy + qmxg[x]["offset"] 
xglx = qmxg[x]["type"] 
xgsz = qmxg[x]["value"] 
xgdj = qmxg[x]["freeze"] 
if xgdj == nil or xgdj == "" then 
gg.setValues({[1] = {address = xgpy, flags = xglx, value = xgsz}})
else 
gg.addListItems({[1] = {address = xgpy, flags = xglx, freeze = xgdj, value = xgsz}}) end 
xgsl = xgsl + 1 
xgjg = true end 
return xgsl  -- 返回修改的数量
end 

function xqmnb(qmnb) 
gg.clearResults() 
gg.setRanges(qmnb[1]["memory"]) 
gg.searchNumber(qmnb[3]["value"], qmnb[3]["type"]) 
if gg.getResultCount() == 0 then 
gg.toast(qmnb[2]["name"] .. "开启失败") 
return 0  -- 返回0表示没有修改
else 
gg.refineNumber(qmnb[3]["value"], qmnb[3]["type"])
gg.refineNumber(qmnb[3]["value"], qmnb[3]["type"]) 
gg.refineNumber(qmnb[3]["value"], qmnb[3]["type"]) 
if gg.getResultCount() == 0 then 
gg.toast(qmnb[2]["name"] .. "开启失败") 
return 0  -- 返回0表示没有修改
else 
        local resultCount = gg.getResultCount()
        local maxResults = math.min(resultCount, 999999)
        sl = gg.getResults(maxResults) 
        sz = #sl  -- 使用实际获取的结果数量
        
        local xgsl = 0  -- 改为局部变量
        local xgjg = false  -- 改为局部变量
        
        for i = 1, sz do 
            if sl[i] == nil or sl[i].address == nil then
                -- 跳过无效的结果
                goto continue
            end
            
            pdsz = true 
            for v = 4, #(qmnb) do 
                if pdsz == true then 
                    pysz = {} 
                    pysz[1] = {} 
                    pysz[1].address = sl[i].address + qmnb[v]["offset"] 
                    pysz[1].flags = qmnb[v]["type"] 
                    szpy = gg.getValues(pysz) 
                    
                    if szpy == nil or szpy[1] == nil or szpy[1].value == nil then
                        pdsz = false
                        goto condition_check
                    end
                    
                    pdpd = qmnb[v]["lv"] .. ";" .. szpy[1].value 
                    szpd = split(pdpd, ";") 
                    tzszpd = szpd[1] 
                    pyszpd = szpd[2] 
                    
                    if tzszpd == pyszpd then 
                        pdjg = true 
                        pdsz = true 
                    else 
                        pdjg = false 
                        pdsz = false 
                    end 
                    
                    ::condition_check::
                end 
            end 
            
            if pdjg == true then 
                szpy = sl[i].address 
                local modified = xgxc(szpy, qmxg)  -- 获取返回的修改数量
                xgsl = xgsl + modified  -- 累加修改数量
                xgjg = true 
            end 
            
            ::continue::
        end 
        
        if xgjg == true then 
            gg.toast(qmnb[2]["name"] .. "开启成功" .. xgsl .. "条数据") 
            return xgsl  -- 返回修改的数量
        else 
            gg.toast(qmnb[2]["name"] .. "开启失败") 
            return 0  -- 返回0表示没有修改
        end 
    end 
end 
end

-- 全局变量
local loopEnabled = false
local loopKillCount = 0
local loopLastTime = 0
local speedUpEnabled = false
local speedUpAddresses = {}

-- 城墙无敌函数
function ExecuteWallInvincible()
    local modifyCount = 0
    
    -- 塔和拒马无敌
    qmnb = {
        {["memory"] = 32},
        {["name"] = "塔，拒马无敌"},
        {["value"] = 1086077184, ["type"] = 4},
        {["lv"] = 1072693248, ["offset"] = 528, ["type"] = 4},
        {["lv"] = -2, ["offset"] = 532, ["type"] = 4},
    }
    qmxg = {
        {["value"] = 999999999, ["offset"] = 556, ["type"] = 4},
    }
    local result = xqmnb(qmnb)
    modifyCount = modifyCount + (result or 0)  -- 使用or 0确保不会加nil
    gg.clearResults()

    -- 城墙无敌 (取消冻结)
    qmnb = {
        {["memory"] = 32},
        {["name"] = "城墙无敌"},
        {["value"] = -1064763392, ["type"] = 4},
        {["lv"] = 1072693248, ["offset"] = 704, ["type"] = 4},
    }
    qmxg = {
        {["value"] = 999999999, ["offset"] = 620, ["type"] = 4},
    }
    result = xqmnb(qmnb)
    modifyCount = modifyCount + (result or 0)  -- 使用or 0确保不会加nil
    gg.clearResults()
    
    gg.toast("城墙无敌修改了" .. modifyCount .. "条数据")
    return modifyCount
end



function Main0()
    local SN = gg.choice({
        "开始循环",
        "停止循环",
        "检查更新", -- 新增选项
        "退出脚本",
    }, nil, "")
    if SN == 1 then
        StartLoop()
    end
    if SN == 2 then
        StopLoop()
    end
    if SN == 3 then -- 新增的更新检查
        ManualCheckUpdate()
        Main0() -- 返回菜单
    end
    if SN == 4 then
        os.exit()
    end      
end


-- 秒杀函数
function ExecuteKill()
    local modifyCount = 0
    
    -- 小兵秒杀
    qmnb = {
        {["memory"] = 32},
        {["name"] = "小兵秒杀"},
        {["value"] = 1082617856, ["type"] = 4},
        {["lv"] = -1074790400, ["offset"] = 16, ["type"] = 4},
        {["lv"] = -2, ["offset"] = 20, ["type"] = 4},
    }
    qmxg = {
        {["value"] = 100, ["offset"] = 44, ["type"] = 4},
    }
    local result = xqmnb(qmnb)
    modifyCount = modifyCount + (result or 0)
    gg.clearResults()
    
    -- 精英秒杀
    qmnb = {
        {["memory"] = 32},
        {["name"] = "精英秒杀"},
        {["value"] = 1082617856, ["type"] = 4},
        {["lv"] = 2, ["offset"] = -88, ["type"] = 4},
        {["lv"] = -1074790400, ["offset"] = 16, ["type"] = 4},
        {["lv"] = -2, ["offset"] = 20, ["type"] = 4},
    }
    qmxg = {
        {["value"] = 100, ["offset"] = 44, ["type"] = 4, ["freeze"] = true},
    }
    result = xqmnb(qmnb)
    modifyCount = modifyCount + (result or 0)
    gg.clearResults()
    
    -- BOSS秒杀
    qmnb = {
        {["memory"] = 32},
        {["name"] = "BOSS秒杀"},
        {["value"] = 1082617856, ["type"] = 4},
        {["lv"] = 4, ["offset"] = -88, ["type"] = 4},
        {["lv"] = -1074790400, ["offset"] = 16, ["type"] = 4},
        {["lv"] = -2, ["offset"] = 20, ["type"] = 4},
    }
    qmxg = {
        {["value"] = 100, ["offset"] = 44, ["type"] = 4, ["freeze"] = true},
    }
    result = xqmnb(qmnb)
    modifyCount = modifyCount + (result or 0)
    gg.clearResults()
    
    gg.toast("秒杀修改了" .. modifyCount .. "条数据")
    return modifyCount
end

-- 加速函数 (固定为5倍)
function ExecuteSpeedUp()
    gg.toast("正在开启5倍加速...")
    qmnb = {
        {["memory"] = 32},
        {["name"] = "加速"},
        {["value"] = 9.305824292495217E-25, ["type"] = 16},
        {["lv"] = 0.3333333432674408, ["offset"] = -892, ["type"] = 16},
        {["lv"] = 0.029999999329447746, ["offset"] = -888, ["type"] = 16},       
    }
    -- 搜索内存地址
    gg.searchNumber(9.305824292495217E-25, 16)
    
    -- 获取搜索结果
    local results = gg.getResults(100)
    if #results > 0 then
        -- 准备修改列表
        local modifyList = {}
        
        for i, v in ipairs(results) do
            -- 计算目标地址 (偏移 -896)
            local targetAddress = v.address - 896
            
            -- 添加到修改列表，固定为5倍加速
            table.insert(modifyList, {
                address = targetAddress,
                value = 5,  -- 固定为5倍
                flags = 16,
                freeze = true  -- 保持冻结状态
            })
        end
        
        -- 应用修改
        gg.setValues(modifyList)
        gg.addListItems(modifyList)
        
        -- 保存加速地址到全局变量，以便后续检查
        speedUpAddresses = modifyList
        speedUpEnabled = true
        
        gg.toast("5倍加速开启成功")
    else
        gg.toast("加速开启失败")
    end
    gg.clearResults()
end

-- 检查并保持加速的函数
function MaintainSpeedUp()
    if not speedUpEnabled or #speedUpAddresses == 0 then
        return
    end
    
    -- 检查并修复加速
    local values = gg.getValues(speedUpAddresses)
    local needRepair = false
    
    for i, v in ipairs(values) do
        -- 如果值不是5，需要修复
        if math.abs(v.value - 5) > 0.1 then
            needRepair = true
            break
        end
    end
    
    if needRepair then
        -- 重新设置加速值
        for i, v in ipairs(speedUpAddresses) do
            v.value = 5
            v.freeze = true
        end
        gg.setValues(speedUpAddresses)
        gg.addListItems(speedUpAddresses)
    end
end


-- 开始循环
function StartLoop()
    gg.toast("开始执行循环...")
    
    -- 第一步：执行加速
    ExecuteSpeedUp()
    gg.sleep(500)
    
    -- 第二步：执行城墙无敌
    ExecuteWallInvincible()
    gg.sleep(500)
    
    -- 第三步：执行秒杀
    ExecuteKill()
    gg.sleep(500)
    
    -- 启动循环
    loopEnabled = true
    loopKillCount = 1  -- 已经执行了1次秒杀
    loopLastTime = os.time()
    
    gg.toast("循环已开始，每5秒执行一次")
end

-- 停止循环
function StopLoop()
    loopEnabled = false
    speedUpEnabled = false
    speedUpAddresses = {}
    gg.toast("循环已停止")
end

-- 主循环
while true do
    if gg.isVisible(true) then
        gg.setVisible(false)
        Main0()
    end
    
    -- 定期维护加速，确保加速不受影响
    if speedUpEnabled then
        MaintainSpeedUp()
    end
    
    -- 执行循环逻辑
    if loopEnabled then
        local currentTime = os.time()
        
        -- 每5秒执行一次
        if currentTime - loopLastTime >= 5 then
            
            -- 维护加速
            MaintainSpeedUp()
            
            -- 秒杀循环2次后运行1次无敌
            if loopKillCount < 2 then
                -- 执行秒杀
                ExecuteKill()
                loopKillCount = loopKillCount + 1
                gg.toast("执行秒杀 (第" .. loopKillCount .. "次)")
            else
                -- 执行城墙无敌
                local modifyCount = ExecuteWallInvincible()
                loopKillCount = 0  -- 重置秒杀计数
                gg.toast("执行城墙无敌，修改了" .. modifyCount .. "条数据")
            end
            
            -- 再次维护加速
            MaintainSpeedUp()
            
            loopLastTime = currentTime
        end
    end
    
    gg.sleep(500)
end