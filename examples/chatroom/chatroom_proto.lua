local sprotoparser = require "sprotoparser"

local proto = {}

proto.c2s = sprotoparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}

create 1 {
    request {
    }
	response {
		roomid 0  : integer
        msg 1   : string
	}
}

join 2 {
    request {
        roomid 0 : integer 
    }
    response {
        ret 0 : integer 
        roomid 1 : integer
        msg 2: string
    }
}

chat 3 {
	request {
        roomid 0 : integer
		msg 1 : string
	}
	response {
		ret 0 : integer
        msg 1 : string
	}
}

exit 4 {
	request {
	}
    response {
        ret 0 : integer 
        msg 1 : string
    }
}

]]

--TODO sync 支持结构体数组
proto.s2c = sprotoparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}

sync 1 {
    request {
        uin 0: integer
        msg 1 : string 
    }
}
]]

return proto
