local fs = require("@lune/fs") :: any
local serde = require("@lune/serde") :: any

local excludeFromView = {
    [".vscode"] = true,
    ["lib"] = true,
    ["node_modules"] = true,
    ["src/scripts"] = true,
    [".gitattributes"] = true,
    [".luaurc"] = true,
    ["aftman.toml"] = true,
    ["package-lock.json"] = true,
    ["package.json"] = true,
    ["selene.toml"] = true,
    ["sourcemap.json"] = true,
}
local ignoreFromGit = {
    ".vscode",
    "lib",
    "node_modules",
    ".luaurc",
    "aftman.toml",
    "selene.toml",
    "sourcemap.json",
}
local toCreate = {
    { `.gitattributes`, `*.luau linguist-language=Lua` },
    { `.gitignore`, table.concat(ignoreFromGit, "\n") },
    { `.luaurc`, serde.encode( "json", { lint = { ["*"] = true } }) },
}
local toDelete = {
    ".editorconfig",
    `game.sublime-project`,
    `roblox.yml`,
    `README.md`,
}

local function createFiles(source)
    fs.writeDir(`{source}/.vscode`)
    fs.writeFile(`{source}/.vscode/settings.json`, serde.encode("json", { ["files.exclude"] = excludeFromView }))

    for _, entry in toCreate do
        local name, context = table.unpack(entry)

        if fs.isFile(`{source}\\{name}`) then
            continue
        end

        fs.writeFile(`{source}\\{name}`, context or "")
    end
end

local function deleteFiles(source)
    for _, entry in fs.readDir(source) do
        if not table.find(toDelete, entry) then
            continue
        end

        fs.removeFile(`{source}\\{entry}`)
    end
end

local function writeDir(origin: string, target: string?)
    assert(origin, "Bad origin")

    for _, result in { origin, target :: string } do
        if fs.isDir(result) then
            continue
        end

        fs.writeDir(result)
    end

    if not target then
        return
    end

    for _, result in fs.readDir(origin) do
        local originalPath = `{origin}\\{result}`
        local targetPath = `{target}\\{result}`

        if fs.isFile(originalPath) then
            local ok, results = pcall(fs.readFile, originalPath)

            if not ok then
                continue
            end

            if not (
                string.find(targetPath, "lib") or
                string.find(targetPath, "node_modules") or
                string.find(targetPath, "packages")
            ) then
                local nameBeforeExtension = string.match(result, "^(.+)%..+$")
                local extension = string.match(result, "^.*%.(.+)$")

                if extension == "lua" then
                    extension = "luau"
                    targetPath = `{target}\\{nameBeforeExtension}.{extension}`
                end
            end

            fs.writeFile(targetPath, results)
        else
            writeDir(originalPath, targetPath)
        end
    end
end

local function setup()
    local args, count = {}, #process.args
    local cwd = string.sub(process.cwd, 1, -2)

    args.name = "Game"

    if count == 1 then
        args.name = process.args[1] or args.name
    elseif count >= 2 then
        for i = 2, #process.args, 2 do
            local key = process.args[i - 1]
            local value = process.args[i]

            args[key] = value
        end
    end

    local luneTemp = process.env["TEMP"] do
        if not luneTemp then
            error("TEMP not found")
    
            return
        end
    
        luneTemp ..= "\\.lune"
    
        if not fs.isDir(luneTemp) then
            fs.writeDir(luneTemp)
        end
    end

    local canCreateFiles = (args.forceUpdate == "true")

    if not canCreateFiles then
        for _, fileToCreate in toCreate do
            if fs.isFile(`{luneTemp}\\{fileToCreate[1]}`) then
                continue
            end

            canCreateFiles = true

            break
        end
    end

    if canCreateFiles then
        createFiles(luneTemp)

        for _, command in {
            `npx @quenty/nevermore-cli init {args.name}`,
            "aftman add Kampfkarren/selene",
            "aftman add rojo-rbx/rojo",
            "aftman install",
            `cd lib && git clone https://github.com/Elttob/Fusion && cd ..`,
        } do
            if not fs.isDir(`{luneTemp}/lib`) then
                fs.writeDir(`{luneTemp}/lib`)
            end

            process.spawn("cmd", { "/c", command }, { cwd = luneTemp })
        end
    end

    local projectFile = `{luneTemp}/default.project.json`
    local projectFileContents = serde.decode("json", fs.readFile(projectFile))

    projectFileContents["tree"]["ServerScriptService"]["Game"]["packages"]["@elttob"] = {
        ["$className"] = "Folder",
        ["fusion"] = {
            ["$className"] = "Folder",
            ["Shared"] = {
                ["$className"] = "Folder",
                ["Fusion"] = {
                    ["$path"] = "lib/Fusion",
                },
            },
        },
    }

    fs.writeFile(projectFile, serde.encode("json", projectFileContents))

    deleteFiles(luneTemp)
    writeDir(luneTemp, cwd)
end

setup()
