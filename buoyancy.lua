local buoyancy = {}

function buoyancy.init(voxel_size)
   submerged_volume = simCreateOctree(voxel_size,0,1)
   water_level = 0
   graph_handle = simGetObjectHandle("Graph")
end

function buoyancy.do_buoyancy(boat)
   --get boat position and velocity
   p=simGetObjectPosition(boat,-1)
   linVel, angVel = simGetObjectVelocity(boat)
   --clear occupancy tree of old voxels
   simRemoveVoxelsFromOctree(submerged_volume,0,nil)
   simInsertObjectIntoOctree(submerged_volume,boat,0)
   --remove voxels above water level
   local voxels = simGetOctreeVoxels(submerged_volume)
   local to_remove = {}
   local dt = simGetSimulationTimeStep()
   local dz = dt*linVel[3]
   for i = 3,table.getn(voxels),3 do
      if (voxels[i]+dz)+water_level> 0 then
	 to_remove[#to_remove+1] = voxels[i-2]
	 to_remove[#to_remove+1] = voxels[i-1]
	 to_remove[#to_remove+1] = voxels[i]
      end
   end
   if table.getn(to_remove) > 1 then
      simRemoveVoxelsFromOctree(submerged_volume,1,to_remove)
   end
   voxels = simGetOctreeVoxels(submerged_volume)
   local verts, indeces
   if table.getn(voxels) > 9 then
      --construct a convex hull using voxels below water level
      verts,indeces = simGetQHull(voxels)
   end
   --remove old mech from scene
   if shape ~= nil then
      simRemoveObject(shape)
      shape = nil
   end
   if verts ~= nil then
      --create mesh from hull and calculate it's volume and center of mass
      shape = simCreateMeshShape(1,20,verts,indeces)
      local code = simComputeMassAndInertia(shape,1000)
      if code == 1 then
	 --calculate buoyant force and transform it to correct reference frame
	 local om = simGetObjectMatrix(boat,-1)
	 local mass, inertia, cm = simGetShapeMassAndInertia(shape,om)
	 om[4] = 0
	 om[8] = 0
	 om[12]= 0
	 simInvertMatrix(om)
	 local force = {0,0,mass*9.81};
	 local appliedForce = simMultiplyVector(om,force)
         --apply forces to boat
         simAddForce(boat,cm,appliedForce)
	 --simAddForceAndTorque(boat,force)
         --setup graph and plot debug data 
	 simHandleGraph(graph_handle,simGetSimulationTime()+simGetSimulationTimeStep())
	 simSetGraphUserData(graph_handle,"cm_x",cm[1])
	 simSetGraphUserData(graph_handle,"cm_y",cm[2])
	 simSetGraphUserData(graph_handle,"cm_z",cm[3])
	 simSetGraphUserData(graph_handle,"f_x",appliedForce[1]/9.81/mass/20)
	 simSetGraphUserData(graph_handle,"f_y",appliedForce[2]/9.81/mass/20)
	 simSetGraphUserData(graph_handle,"f_z",appliedForce[3]/9.81/mass/20)
      end
   end
end
   
return buoyancy
