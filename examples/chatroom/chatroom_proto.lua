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
        msg 1: string
    }
}

chat 3 {
	request {
		msg 0 : string
	}
	response {
		ret 0 : integer
	}
}

exit 4 {
	request {
        roomid 0 : integer
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
    response {
        msg 0 : string 
    }
}
]]

return proto
