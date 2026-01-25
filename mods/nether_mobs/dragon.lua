
local S = minetest.get_translator("nether_mobs")
local scale_item = "nether_mobs:dragon_scale"

minetest.register_craftitem("nether_mobs:dragon_scale", {
    description = S("Nether Dragon Scale"),
    inventory_image = "nether_dragon_scale.png",
    groups = {armor_material = 1}
})

-- BLACKLIST for dragon fire (nodes immune)
local blacklist = {
    "default:obsidian",
    "default:obsidian_block",
    "default:obsidianbrick",
    "stairs:slab_obsidian",
    "stairs:slab_obsidian_block",
    "stairs:slab_obsidianbrick",
    "stairs:stair_obsidian",
    "stairs:stair_obsidian_block",
    "stairs:stair_obsidianbrick",
    "nether:portal",
}

-- Dragon Scale Node
minetest.register_node("nether_mobs:dragon_scale_block", {
    description = S("Nether Dragon Scale Block"),
    tiles = {"nether_dragon_scale_block_top.png", "nether_dragon_scale_block_top.png", "nether_dragon_scale_block.png"},
    paramtype = "facedir",
    is_ground_content = false,
    groups = {cracky = 1, level = 3},
    sounds = default.node_sound_stone_defaults(),
    on_place = minetest.rotate_node
})

-- Dragon Breath Arrow
mobs:register_arrow("nether_mobs:dragon_breath", {
    visual = "sprite",
    visual_size = {x=1, y=1},
    textures = {"nether_dragon_fire.png"},
    collisionbox = {-0.1,-0.1,-0.1,0.1,0.1,0.1},
    velocity = 7,
    tail = 1,
    tail_texture = "nether_dragon_fire.png",
    tail_size = 10,
    glow = 5,
    expire = 0.1,
    on_activate = function(self) self.object:set_armor_groups({immortal = 1}) end,
    hit_player = function(self, player)
        player:punch(self.object, 1.0, {full_punch_interval=1.0, damage_groups={fleshy=18}}, nil)
    end,
    hit_mob = function(self, mob)
        mob:punch(self.object, 1.0, {full_punch_interval=1.0, damage_groups={fleshy=28}}, nil)
    end
})

-- Animation sets
local animation_fly = {speed_normal=10, speed_sprint=20, stand_start=140, stand_end=160, walk_start=110, walk_end=130}

-- Nether Dragon (wild)
mobs:register_mob("nether_mobs:dragon", {
    type = "monster",
    hp_min = 350,
    hp_max = 400,
    armor = 85,
    walk_velocity = 3,
    run_velocity = 5,
    fly = true,
    fly_in = "air",
    pushable = false,
    view_range = 60,
    damage = 44,
    attack_type = "dogshoot",
    arrow = "nether_mobs:dragon_breath",
    shoot_interval = 1,
    visual = "mesh",
    visual_size = {x=20, y=20}, -- dragon stays huge
    collisionbox = {-1.3,-1.0,-1.3,1.3,1.8,1.3},
    textures = {{"mobs_nether_dragon.png"}},
    mesh = "mobs_nether_dragon.b3d",
    animation = animation_fly,
    drops = {
        {name="mobs:meat_raw", chance=1, min=22, max=33},
        {name="nether_mobs:dragon_scale", chance=1, min=2, max=5}
    }
})


-- Tamed Nether Dragon
mobs:register_mob("nether_mobs:tamed_dragon", {
    type = "npc",
    hp_min = 100,
    hp_max = 200,
    armor = 80,
    walk_velocity = 3,
    run_velocity = 5,
    fly = true,
    fly_in = "air",
    pushable = false,
    view_range = 60,
    damage = 34,
    attack_type = "dogshoot",
    arrow = "nether_mobs:dragon_breath",
    shoot_interval = 1,
    visual = "mesh",
    visual_size = {x=20, y=20}, -- dragon stays huge
    collisionbox = {-1.3,-1.0,-1.3,1.3,1.8,1.3},
    textures = {{"mobs_nether_dragon_child.png"}},
    mesh = "mobs_nether_dragon.b3d",
    animation = {speed_normal=10, speed_sprint=20, stand_start=140, stand_end=160, walk_start=110, walk_end=130},
    tamed = true,

    do_custom = function(self, dtime)
        if not self.v3 then
            self.v2 = 0
            self.v3 = true
            self.max_speed_forward = 12
            self.max_speed_reverse = 4
            self.accel = 6

            -- attach player on dragon back
            self.driver_attach_at = {x=0, y=1, z=0}

            -- camera above dragon head
            self.driver_eye_offset = {x=0, y=26, z=0}

            -- force driver scale 1x1
            self.driver_scale = {x=1, y=1}
        end

        if self.driver then
            -- drive normally
            mobs.drive(self, "walk", "stand", true, dtime)

            -- force player normal size every tick
            self.driver:set_properties({visual_size={x=1, y=1}})

            return false
        end

        return true
    end,

    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then return end

        -- tame/feed
        if mobs:feed_tame(self, clicker, 10, true, true) then return end

        -- detach if already riding
        if self.driver and clicker == self.driver then
            mobs.detach(clicker, {x=1, y=0, z=1})
            clicker:set_properties({visual_size={x=1, y=1}})
            return
        end

        -- attach if has saddle
        local inv = clicker:get_inventory()
        if (not self.driver and clicker:get_wielded_item():get_name()=="mobs:saddle") or self.saddle then
            self.object:set_properties({stepheight=1.1})
            mobs.attach(self, clicker)

            if not self.saddle then
                inv:remove_item("main", "mobs:saddle")
            end
            self.saddle = true

            -- immediately set player normal size
            self.driver:set_properties({visual_size={x=1, y=1}})
        end
    end
})

-- Auto-spawn wild Nether Dragons
if not nethermobs.custom_spawn then
    mobs:spawn({
        name = "nether_mobs:dragon",
        nodes = {"nether:rack", "nether:rack_deep"},
        neighbors = nil,
        min_height = -11000,
        max_height = -5000,
        interval = 8,
        chance = 500,
        active_object_count = 1, 
        on_spawn = function(self, pos)
            pos.y = pos.y + 0.5
            mobs:effect(pos, 30, "nether_particle.png", 0.1, 2, 3, 5)
            pos.y = pos.y + 0.25
            mobs:effect(pos, 30, "nether_particle.png", 0.1, 2, 3, 5)
        end,
    })
end



-- Eggs
mobs:register_egg("nether_mobs:dragon", S("Nether Dragon"), "nether_sand.png^nether_dragon_fire.png", 1)
mobs:register_egg("nether_mobs:tamed_dragon", S("Tamed Nether Dragon"), "mobs_chicken_egg.png^(nether_sand.png^fire_basic_flame.png^[mask:mobs_chicken_egg_overlay.png)", 1)
