# 最终PCK目录只读检查程序（2026-10-12）

检查实际PCK字节，不把export日志或源码exclude投影当目录证明。按[Godot 4.7官方读取器](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/core/io/file_access_pack.cpp)与[格式常量](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/core/io/file_access_pack.h)核对：仅独立v3/v4、不处理嵌入EXE、加密、稀疏或差分包，不读取任何密钥。未知格式/目录越界/截断/标记项/非法路径/重复条目拒绝。

下列函数已只读执行于历史`native-retired-audio-pack-v1/game.pck`，实际格式4/引擎4.7.0/6074540字节/594项，与原`directory-report.json`键集差异0，前后SHA保持`07964613f2db5463f23c57c9d70cc3e4e31d5adb636f2d836257201d9a52cbec`。还真实找到9个旧PNG缓存，符合历史缺口；**不是新最终包通过**。

最终新候选完成后，在它实际独立目录运行此函数，并保存实际SHA/完整目录。核对制作目录、旧图源/import/ctex和旧音效、字体/媒体依赖，同时检查当前24生产身体的remap/资源与运行夹具。源和导出政策当前投影为0外部媒体，不免除新PCK实际检查。

```powershell
$ErrorActionPreference='Stop'
function Read-PckDirectory([string]$path) {
    $stream=[IO.File]::OpenRead($path);$reader=[IO.BinaryReader]::new($stream)
    try {
        if($reader.ReadUInt32() -ne 0x43504447){throw 'Standalone PCK magic mismatch'}
        $version=$reader.ReadUInt32();$major=$reader.ReadUInt32();$minor=$reader.ReadUInt32();$patch=$reader.ReadUInt32()
        if($version -notin @(3,4)){throw 'This readonly audit supports only standalone PCK v3/v4'}
        $flags=$reader.ReadUInt32();$fileBase=$reader.ReadUInt64();$directory=$reader.ReadUInt64()
        if(($flags -band 1) -or ($flags -band 4)){throw 'Encrypted/sparse packs not audited; no key access'}
        if($directory -ge $stream.Length){throw 'Directory offset outside pack'}
        $stream.Position=[long]$directory
        $count=$reader.ReadUInt32()
        if($count -lt 1 -or $count -gt 100000){throw 'Invalid directory count'}
        $entries=[Collections.Generic.List[string]]::new()
        $encoding=[Text.UTF8Encoding]::new($false,$true)
        for($i=0;$i -lt $count;$i++){
            $size=$reader.ReadUInt32()
            if($size -lt 1 -or $size -gt 16384 -or $stream.Position+$size+36 -gt $stream.Length){throw 'Truncated/invalid path record'}
            $entry=$encoding.GetString($reader.ReadBytes($size)).TrimEnd([char]0)
            $offset=$reader.ReadUInt64();$length=$reader.ReadUInt64();$md5=$reader.ReadBytes(16);$fileFlags=$reader.ReadUInt32()
            if($fileFlags -ne 0 -or $entry -match '(^|/)\.\.(/|$)|\\' -or $entry.StartsWith('/') -or $entry.Contains([char]0)){throw 'Unexpected flagged/unsafe pack entry'}
            if($fileBase+$offset -gt $stream.Length -or $length -gt $stream.Length-($fileBase+$offset)){throw 'Payload span outside pack'}
            $entries.Add($entry)
        }
        if(@($entries|Select-Object -Unique).Count -ne $count){throw 'Duplicate directory entry'}
        return [pscustomobject]@{format=$version;engine=@($major,$minor,$patch);pack_flags=$flags;bytes=$stream.Length;entry_count=$count;entries=@($entries|Sort-Object)}
    } finally {$reader.Dispose();$stream.Dispose()}
}
```

此文件只提供只读检查函数；调用路径应使用已实际导出的明确候选。不要为了报告好看覆写旧包/旧目录报告，或把历史目录的0差异当新候选的版权/全部资源验收。
