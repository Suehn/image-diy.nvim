local ffi = require("ffi")

-- 初始缓存大小
local cached_size = {
  screen_x = 800, -- 默认宽度
  screen_y = 600, -- 默认高度
  screen_cols = 80, -- 默认列数
  screen_rows = 24, -- 默认行数
  cell_width = 10, -- 默认单元格宽度
  cell_height = 25, -- 默认单元格高度
}

-- 更新大小函数
local update_size = function()
  ffi.cdef([[
    typedef struct {
      unsigned short row;
      unsigned short col;
      unsigned short xpixel;
      unsigned short ypixel;
    } winsize;
    int ioctl(int, int, ...);
  ]])

  local TIOCGWINSZ = nil
  if vim.fn.has("linux") == 1 then
    TIOCGWINSZ = 0x5413
  elseif vim.fn.has("mac") == 1 then
    TIOCGWINSZ = 0x40087468
  elseif vim.fn.has("bsd") == 1 then
    TIOCGWINSZ = 0x40087468
  end

  ---@type { row: number, col: number, xpixel: number, ypixel: number }
  local sz = ffi.new("winsize")
  local success, err = pcall(function()
    assert(ffi.C.ioctl(1, TIOCGWINSZ, sz) == 0, "Failed to get terminal size")
  end)

  if not success then
    -- 设置退化的默认值
    sz.row = 24
    sz.col = 80
    sz.xpixel = 800
    sz.ypixel = 600
    -- print("Warning: Using default terminal size values due to error: " .. err)
  end

  cached_size = {
    screen_x = sz.xpixel,
    screen_y = sz.ypixel,
    screen_cols = sz.col,
    screen_rows = sz.row,
    cell_width = sz.xpixel / sz.col,
    cell_height = sz.ypixel / sz.row,
  }
end

-- 初始更新大小
update_size()

-- 自动命令在终端大小变化时更新
vim.api.nvim_create_autocmd("VimResized", {
  callback = update_size,
})

-- 获取TTY
local get_tty = function()
  local handle = io.popen("tty 2>/dev/null")
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  result = vim.fn.trim(result)
  if result == "" then return nil end
  return result
end

-- 返回接口
return {
  get_size = function()
    return cached_size
  end,
  get_tty = get_tty,
}
