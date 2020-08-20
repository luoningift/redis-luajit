local course_id = KEYS[1]
local student_uid = KEYS[2]
local course_key = 'course:'.. course_id
local student_key = 'study:'.. course_id ..":".. student_uid

local course_info = redis.call('get', course_key)
local student_info = redis.call('JSON.GET', student_key)
if course_info ~= nil and course_info ~= false then
   course_info = cjson.decode(course_info)
end
if student_info ~= nil and student_info ~= false then
   student_info = cjson.decode(student_info)
end

if (student_info == false or not next(student_info)) or (course_info == false or not next(course_info)) then
    local mysql = require "luasql.mysql"
    local env = mysql.mysql();
    local errorString, cursor;
    local conn = env:connect("db_name", "user", "password", "host", 3306)
    if student_info == false or not next(student_info) then
       student_info = {content = {}, group = {}}
       cursor, errorString = conn:execute("select content_id from content_study_progress where student_uid = " .. student_uid .. " and course_id = " .. course_id)
       local row = cursor:fetch({}, "a")
       local i = 1
       while row do
	    student_info.content["c" .. row.content_id] = tonumber(row.content_id)
            row = cursor:fetch (row, "a")
            i = i + 1
       end
       cursor:close()
       cursor, errorString = conn:execute("select group_id, course_id, chapter_id, section_id from group_student where student_uid = " .. student_uid .. " and course_id = " .. course_id)
       row = cursor:fetch({}, "a")
       i = 1
       while row do
	    student_info.group["c" .. row.group_id] = {group_id = tonumber(row.group_id), course_id = tonumber(row.course_id), chapter_id = tonumber(row.chapter_id), section_id = tonumber(row.section_id) }
            row = cursor:fetch (row, "a")
            i = i + 1
       end
       cursor:close()
       redis.call('JSON.SET', student_key, '.',  cjson.encode(student_info));	
       redis.call('expire', student_key, 86400)
    end
    if course_info == false or not next(course_info) then
       course_info = {content = {}, group = {}}
       cursor, errorString = conn:execute("select group_id, course_id, chapter_id, section_id from `group` where  course_id = " .. course_id)
       row = cursor:fetch({}, "a")
       i = 1
       while row do
            course_info.group[i] = {group_id = tonumber(row.group_id), course_id = tonumber(row.course_id), chapter_id = tonumber(row.chapter_id), section_id = tonumber(row.section_id) }
            row = cursor:fetch (row, "a")
	    i = i + 1
       end
       cursor:close()
       cursor, errorString = conn:execute("select group_id, content_id from content where  course_id = " .. course_id)
       row = cursor:fetch({}, "a")
       while row do
            if course_info.content["c" .. row.group_id] == nil or not next(course_info.content["c" .. row.group_id]) then
		course_info.content["c" .. row.group_id] = {}
            end
	    local length = #course_info.content["c" .. row.group_id]
	    course_info.content["c" .. row.group_id][length + 1] = tonumber(row.content_id)
            row = cursor:fetch(row, "a")
       end
       redis.call('set', course_key, cjson.encode(course_info))
       redis.call('expire', course_key, 900)
       cursor:close()
    end
    conn:close()
    env:close()
end

local function intersection(t1, t2)
    local res = {}
    for _, value1 in ipairs(t1) do
       local equal = false
       for _, value2 in ipairs(t2) do
           if tonumber(value1) == tonumber(value2) then
               equal = true
               break;
           end
       end
       if equal then
          table.insert(res, 1)
       end
    end
    return #res
end

local function mergetable(...)
    local arrays = { ... }
    local result = {}
    for _,array in ipairs(arrays) do
        for _, v in ipairs(array) do
            table.insert(result, v)
        end
    end

    return result
end

local function progress_format(has_study_count, all_study_count)
   if all_study_count == 0 then
     return 0
   end
   local progress = math.floor(has_study_count * 100 / all_study_count)
   if progress < 1 and progress > 0 then
      progress = 1
   end
   if progress < 100 and progress > 99 then
      progress = 99
   end
   if progress > 100 then
      progress = 100
   end
   return progress
end

local student_content = {}
for _, content_id in pairs(student_info.content) do
   table.insert(student_content, content_id)
end
local student_group = {}
for _, t_group in pairs(student_info.group) do
  table.insert(student_group, t_group)
end
for group_id, content in pairs(course_info.content) do
    course_info.content[group_id] = {#content, intersection(content, student_content)}
end
local group_info = mergetable(course_info.group, student_group)
local course = {0, 0}
local chapter = {}
local section = {}
for _, one in ipairs(group_info) do
    local group_id = one.group_id 
    local chapter_id = one.chapter_id
    local section_id = one.section_id
    if course_info.content[ "c" ..group_id] ~= nil then
	local progress = course_info.content[ "c" ..group_id]
        course[1] = course[1] + progress[1]
        course[2] = course[2] + progress[2]
        if chapter["c" .. chapter_id] == nil then
	    chapter["c" .. chapter_id] = {0, 0}
        end
        if section["c" .. section_id] == nil then
           section["c" .. section_id] = {0, 0}
        end
	chapter["c" .. chapter_id][1] = chapter["c" .. chapter_id][1] + progress[1]
	chapter["c" .. chapter_id][2] = chapter["c" .. chapter_id][2] + progress[2]
	section["c" .. section_id][1] = section["c" .. section_id][1] + progress[1]
	section["c" .. section_id][2] = section["c" .. section_id][2] + progress[2]
    end
end
for chapter_id, score in pairs(chapter) do
    chapter[chapter_id] = progress_format(score[2], score[1])
    if chapter[chapter_id] == 0 then
       chapter[chapter_id] = nil
    end
end
for section_id, score in pairs(section) do
    section[section_id] = progress_format(score[2], score[1])
    if section[section_id] == 0 then
       section[section_id] = nil
    end
end
return cjson.encode({course = progress_format(course[2], course[1]), chapter = chapter, section = section}) 
