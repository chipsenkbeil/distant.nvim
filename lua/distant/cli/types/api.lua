--- @meta

--- @class ClientApi
--- @field append_file ApiAppendFile
--- @field append_file_text ApiAppendFileText
--- @field copy ApiCopy
--- @field create_dir ApiCreateDir
--- @field exists ApiExists
--- @field metadata ApiMetadata
--- @field read_dir ApiReadDir
--- @field read_file ApiReadFile
--- @field read_file_text ApiReadFileText
--- @field remove ApiRemove
--- @field rename ApiRename
--- @field spawn ApiSpawn
--- @field spawn_lsp ApiSpawnLsp
--- @field spawn_wait ApiSpawnWait
--- @field system_info ApiSystemInfo
--- @field watch ApiWatch
--- @field write_file ApiWriteFile
--- @field write_file_text ApiWriteFileText
--- @field unwatch ApiUnwatch

-------------------------------------------------------------------------------
-- ALIASES
-------------------------------------------------------------------------------

--- @alias ApiError string|boolean
--- @alias FilePath string
--- @alias FileType 'dir'|'file'|'symlink'
--- @alias BinaryData number[]
--- @alias SearchId number

--- @alias ApiAppendFile fun(params:DistantAppendFileParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil
--- @alias ApiAppendFileText fun(params:DistantAppendFileTextParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil
--- @alias ApiCancelSearch fun(params:DistantCancelSearchParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil
--- @alias ApiCapabilities fun(params:DistantCapabilitiesParams, cb?:fun(err:ApiError, res:DistantCapabilities|nil)):ApiError|nil, DistantCapabilities|nil
--- @alias ApiCopy fun(params:DistantCopyParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil
--- @alias ApiCreateDir fun(params:DistantCreateDirParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil
--- @alias ApiExists fun(params:DistantExistsParams, cb?:fun(err:ApiError, res:DistantExists|nil)):ApiError|nil, DistantExists|nil
--- @alias ApiMetadata fun(params:DistantMetadataParams, cb?:fun(err:ApiError, res:DistantMetadata|nil)):ApiError|nil, DistantMetadata|nil
--- @alias ApiReadDir fun(params:DistantReadDirParams, cb?:fun(err:ApiError, res:DistantDirEntries|nil)):ApiError|nil, DistantDirEntries|nil
--- @alias ApiReadFile fun(params:DistantReadFileParams, cb?:fun(err:ApiError, res:DistantBlob|nil)):ApiError|nil, DistantBlob|nil
--- @alias ApiReadFileText fun(params:DistantReadFileTextParams, cb?:fun(err:ApiError, res:DistantText|nil)):ApiError|nil, DistantText|nil
--- @alias ApiRemove fun(params:DistantRemoveParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil
--- @alias ApiRename fun(params:DistantRenameParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil
--- @alias ApiSpawn fun(params:DistantSpawnParams, cb?:fun(err:ApiError, res:DistantProcSpawned|nil)):ApiError|nil, DistantProcSpawned|nil
--- @alias ApiSpawnLsp fun(params:DistantSpawnLspParams, cb?:fun(err:ApiError, res:DistantProcSpawned|nil)):ApiError|nil, DistantProcSpawned|nil
--- @alias ApiSpawnWait fun(params:DistantSpawnWaitParams, cb?:fun(err:ApiError, res:DistantProcOutput|nil)):ApiError|nil, DistantProcOutput|nil
--- @alias ApiSearch fun(params:DistantSearchParams, cb?:fun(err:ApiError, res:DistantSearcher|nil)):ApiError|nil, DistantSearcher|nil
--- @alias ApiSystemInfo fun(params:DistantSystemInfoParams, cb?:fun(err:ApiError, res:DistantSystemInfo|nil)):ApiError|nil, DistantSystemInfo|nil
--- @alias ApiWatch fun(params:DistantWatchParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil
--- @alias ApiWriteFile fun(params:DistantWriteFileParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil
--- @alias ApiWriteFileText fun(params:DistantWriteFileTextParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil
--- @alias ApiUnwatch fun(params:DistantUnwatchParams, cb?:fun(err:ApiError, res:DistantOk|nil)):ApiError|nil, DistantOk|nil

-------------------------------------------------------------------------------
-- REQUEST TYPES
-------------------------------------------------------------------------------

--- @class DistantAppendFileParams
--- @field path FilePath
--- @field data BinaryData

--- @class DistantAppendFileTextParams
--- @field path FilePath
--- @field text string

--- @class DistantCancelSearchParams
--- @field id SearchId

--- @class DistantCapabilitiesParams

--- @class DistantCopyParams
--- @field src FilePath
--- @field dst FilePath

--- @class DistantCreateDirParams
--- @field path FilePath
--- @field all? boolean

--- @class DistantExistsParams
--- @field path FilePath

--- @class DistantMetadataParams
--- @field path FilePath
--- @field canonicalize? boolean
--- @field resolve_file_type? boolean

--- @class DistantReadDirParams
--- @field path FilePath
--- @field depth? number
--- @field absolute? boolean
--- @field canonicalize? boolean
--- @field include_root? boolean

--- @class DistantReadFileParams
--- @field path FilePath

--- @class DistantReadFileTextParams
--- @field path FilePath

--- @class DistantRemoveParams
--- @field path FilePath
--- @field force? boolean

--- @class DistantRenameParams
--- @field src FilePath
--- @field dst FilePath

--- @class DistantSearchParams
--- @field query DistantSearchQuery
--- @field on_match nil|fun(match:DistantSearchMatch)
--- @field on_done nil|fun(matches:DistantSearchMatch[])

--- @class DistantSearchQuery
--- @field target DistantSearchTarget
--- @field condition DistantSearchCondition
--- @field paths FilePath[]
--- @field options nil|DistantSearchOptions

--- @alias DistantSearchTarget 'contents'|'path'

--- @class DistantSearchCondition
--- @field type 'ends_with'|'equals'|'regex'|'starts_with'
--- @field value string

--- @class DistantSearchOptions
--- @field allowed_file_types nil|FileType[]
--- @field include nil|DistantSearchCondition
--- @field exclude nil|DistantSearchCondition
--- @field follow_symbolic_links nil|boolean
--- @field limit nil|number
--- @field max_depth nil|number
--- @field min_depth nil|number
--- @field pagination nil|number

--- @class DistantSpawnParams
--- @field cmd string
--- @field args? string[]
--- @field persist? boolean
--- @field pty? DistantPtySize

--- @class DistantPtySize
--- @field rows number
--- @field cols number
--- @field pixel_width number
--- @field pixel_height number

--- @alias DistantSpawnLspParams DistantSpawnParams

--- @alias DistantSpawnWaitParams DistantSpawnParams

--- @class DistantSystemInfoParams

--- @class DistantWatchParams
--- @field path FilePath
--- @field recursive? boolean
--- @field only? DistantChangeKind[]
--- @field except? DistantChangeKind[]

--- @class DistantWriteFileParams
--- @field path FilePath
--- @field data BinaryData

--- @class DistantWriteFileTextParams
--- @field path FilePath
--- @field data string

--- @class DistantUnwatchParams
--- @field path FilePath

-------------------------------------------------------------------------------
-- RESPONSE TYPES
-------------------------------------------------------------------------------

--- @class DistantOk

--- @class DistantError
--- @field kind string
--- @field description string

--- @class DistantBlob
--- @field data BinaryData

--- @class DistantText
--- @field data string

--- @alias DistantCapabilities DistantCapability[]

--- @class DistantCapability
--- @field kind string
--- @field description string

--- @class DistantSearchMatch
--- @field type 'path'|'contents'
--- @field path FilePath
--- @field submatches DistantSearchSubmatch[]
---
--- @field lines nil|DistantSearchMatchData #lines that were matched (only for contents type)
--- @field line_number nil|string #starting line of match (only for contents type)
--- @field absolute_offset nil|number #byte offset from start of content (only for contents type)

--- @class DistantSearchSubmatch
--- @field match DistantSearchMatchData
--- @field start number #starting byte offset relative to lines (inclusive)
--- @field end number #ending byte offset relative to lines (exclusive)

--- @class DistantSearchMatchData
--- @field type 'text'|'bytes'
--- @field value string|number[]

--- @class DistantSearcher
--- @field id SearchId
--- @field query DistantSearchQuery
--- @field done boolean
--- @field matches DistantSearchMatch[]
--- @field cancel fun(opts:nil|table, cb:nil|fun())
--- @field on_match nil|fun(match:DistantSearchMatch)
--- @field on_done nil|fun(matches:DistantSearchMatch[])

--- @class DistantDirEntries
--- @field entries DistantDirEntry[]
--- @field errors DistantError[]

--- @class DistantDirEntry
--- @field path FilePath
--- @field file_type DistantFileType
--- @field depth number

--- @alias DistantFileType
---| 'dir'      # is a directory
---| 'file'     # is a file
---| 'symlink'  # is a symlink

--- @class DistantChanged
--- @field kind DistantChangeKind
--- @field paths FilePath[]

--- @alias DistantChangeKind
---| 'access'               # something about a file or directory was accessed, but no specific details were known
---| 'access_close_execute' # a file was closed for executing
---| 'access_close_read'    # a file was closed for reading
---| 'access_close_write'   # a file was closed for writing
---| 'access_open_execute'  # a file was opened for executing
---| 'access_open_read'     # a file was opened for reading
---| 'access_open_write'    # a file was opened for writing
---| 'access_read'          # a file or directory was read
---| 'access_time'          # the access time of a file or directory was changed
---| 'create'               # a file, directory, or something else was created
---| 'content'              # the content of a file or directory changed
---| 'data'                 # the data of a file or directory was modified, but no specific details were known
---| 'metadata'             # the metadata of a file or directory was modified, but no specific details were known
---| 'modify'               # something about a file or directory was modified, but no specific details were known
---| 'remove'               # a file, directory, or something else was removed
---| 'rename'               # a file or directory was renamed, but no specific details were known
---| 'rename_both'          # a file or directory was renamed, and the provided paths are the source and target in that order (from, to)
---| 'rename_from'          # a file or directory was renamed, and the provided path is the origin of the rename (before being renamed)
---| 'rename_to'            # a file or directory was renamed, and the provided path is the result of the rename
---| 'size'                 # a file's size changed
---| 'ownership'            # the ownership of a file or directory was changed
---| 'permissions'          # the permissions of a file or directory was changed
---| 'write_time'           # the write or modify time of a file or directory was changed
---| 'unknown'              # catchall in case we have no insight as to the type of change

--- @class DistantExists
--- @field value boolean

--- @class DistantMetadata
--- @field canonicalized_path? FilePath
--- @field file_type string
--- @field len number
--- @field readonly boolean
--- @field accessed? number
--- @field created? number
--- @field modified? number
--- @field unix? DistantUnixMetadata
--- @field windows? DistantWindowsMetadata

--- @class DistantUnixMetadata
--- @field owner_read boolean   #represents whether or not owner can read from the file
--- @field owner_write boolean  #represents whether or not owner can write to the file
--- @field owner_exec boolean   #represents whether or not owner can execute the file
--- @field group_read boolean   #represents whether or not associated group can read from the file
--- @field group_write boolean  #represents whether or not associated group can write to the file
--- @field group_exec boolean   #represents whether or not associated group can execute the file
--- @field other_read boolean   #represents whether or not other can read from the file
--- @field other_write boolean  #represents whether or not other can write to the file
--- @field other_exec boolean   #represents whether or not other can execute the file

--- @class DistantWindowsMetadata
--- @field archive boolean                  #represents whether or not a file or directory is an archive
--- @field compressed boolean               #represents whether or not a file or directory is compressed
--- @field encrypted boolean                #represents whether or not the file or directory is encrypted
--- @field hidden boolean                   #represents whether or not a file or directory is hidden
--- @field integrity_stream boolean         #represents whether or not a directory or user data stream is configured with integrity
--- @field normal boolean                   #represents whether or not a file does not have other attributes set
--- @field not_content_indexed boolean      #represents whether or not a file or directory is not to be indexed by content indexing service
--- @field no_scrub_data boolean            #represents whether or not a user data stream is not to be read by the background data integrity scanner
--- @field offline boolean                  #represents whether or not the data of a file is not available immediately
--- @field recall_on_data_access boolean    #represents whether or not a file or directory is not fully present locally
--- @field recall_on_open boolean           #represents whether or not a file or directory has no physical representation on the local system (is virtual)
--- @field reparse_point boolean            #represents whether or not a file or directory has an associated reparse point, or a file is a symbolic link
--- @field sparse_file boolean              #represents whether or not a file is a sparse file
--- @field system boolean                   #represents whether or not a file or directory is used partially or exclusively by the operating system
--- @field temporary boolean                #represents whether or not a file is being used for temporary storage

--- @class DistantProcSpawned
--- @field id number

--- @class DistantProcOutput
--- @field success boolean
--- @field exit_code number
--- @field stdout number[]
--- @field stderr number[]

--- @class DistantProcStdout
--- @field id number
--- @field data BinaryData

--- @class DistantProcStderr
--- @field id number
--- @field data BinaryData

--- @class DistantProcDone
--- @field id number
--- @field success boolean
--- @field code? number

--- @class DistantSystemInfo
--- @field family string
--- @field os string
--- @field arch string
--- @field current_dir string
--- @field main_separator string
