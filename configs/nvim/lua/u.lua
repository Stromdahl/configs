local u = {}


----------------------------------------------------------------
------ Table
----------------------------------------------------------------


function u.concat (s)
  local t = { }
  for _,v in ipairs(s) do
      t[#t+1] = tostring(v)
  end
  return table.concat(t,"\n")
end

return u
