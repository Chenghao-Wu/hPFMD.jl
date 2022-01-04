
function force_field(sys::System,field::NoField,comm::MPI.Comm)
    forces=zeros(sys.local_N,3)
    return forces
end

function clear_field!(sys::System)
    for i in 1:sys.num_atomtype
        fill!(sys.local_field[i] , 0.0)    
        fill!(sys.global_field[i] , 0.0)  
        fill!(sys.field_gradient[i] , 0.0)  
    end
end

function SerializeCellIndex(i::Int64,j::Int64,k::Int64,celllength::Int64)
    return 1+(i-1)+(j-1)*celllength+(k-1)*celllength*celllength
end 

function SerializeCellGradIndex(i::Int64,j::Int64,k::Int64,axis::Int64,celllength::Int64)
    return 1+(i-1)+(j-1)*celllength+(k-1)*celllength*celllength+(axis-1)*celllength*celllength*celllength
end 

function particle2cell_vertex(cell_length::Float64,delta_r_x::Float64,delta_r_y::Float64,delta_r_z::Float64,index::Int64)
    if index==1
        return (cell_length-delta_r_x) * (cell_length-delta_r_y) * (cell_length-delta_r_z)
    elseif index==2
        return (cell_length-delta_r_x) * (delta_r_y) * (cell_length-delta_r_z)
    elseif index==3
        return (cell_length-delta_r_x) * (delta_r_y) * (delta_r_z)
    elseif index==4
        return (cell_length-delta_r_x) * (cell_length-delta_r_y) * (delta_r_z)
    elseif index==5
        return (delta_r_x) * (cell_length-delta_r_y) * (cell_length-delta_r_z)
    elseif index ==6
        return (delta_r_x) * (cell_length-delta_r_y) * (delta_r_z)
    elseif index==7
        return (delta_r_x) * (delta_r_y) * (cell_length-delta_r_z)
    elseif index ==8
        return (delta_r_x) * (delta_r_y) * (delta_r_z)
    end
end

function perparticle2cell!(coords::Array{Float64,1},particle2cell::Array{Float64,1},cell_length::Float64,V_cell::Float64)
    delta_r_x=coords[1] - floor(coords[1]/cell_length) * cell_length
    delta_r_y=coords[2] - floor(coords[2]/cell_length) * cell_length
    delta_r_z=coords[3] - floor(coords[3]/cell_length) * cell_length
    particle2cell[1]=particle2cell_vertex(cell_length,delta_r_x,delta_r_y,delta_r_z,1)/V_cell     
    particle2cell[2]=particle2cell_vertex(cell_length,delta_r_x,delta_r_y,delta_r_z,2)/V_cell             
    particle2cell[3]=particle2cell_vertex(cell_length,delta_r_x,delta_r_y,delta_r_z,3)/V_cell          
    particle2cell[4]=particle2cell_vertex(cell_length,delta_r_x,delta_r_y,delta_r_z,4)/V_cell             
    particle2cell[5]=particle2cell_vertex(cell_length,delta_r_x,delta_r_y,delta_r_z,5)/V_cell              
    particle2cell[6]=particle2cell_vertex(cell_length,delta_r_x,delta_r_y,delta_r_z,6)/V_cell          
    particle2cell[7]=particle2cell_vertex(cell_length,delta_r_x,delta_r_y,delta_r_z,7)/V_cell          
    particle2cell[8]=particle2cell_vertex(cell_length,delta_r_x,delta_r_y,delta_r_z,8)/V_cell

end

function particle2cell!(sys::System)
    
    V_cell=sys.mesh.cell_length*sys.mesh.cell_length*sys.mesh.cell_length
    for i in 1:sys.local_N
        delta_r=sys.coords[i,1:3] .- floor.(sys.coords[i,1:3]/sys.mesh.cell_length) .* sys.mesh.cell_length
        sys.particle2cell[i,1]=particle2cell_vertex(sys.mesh.cell_length,delta_r,1)/V_cell     
        sys.particle2cell[i,2]=particle2cell_vertex(sys.mesh.cell_length,delta_r,2)/V_cell             
        sys.particle2cell[i,3]=particle2cell_vertex(sys.mesh.cell_length,delta_r,3)/V_cell          
        sys.particle2cell[i,4]=particle2cell_vertex(sys.mesh.cell_length,delta_r,4)/V_cell             
        sys.particle2cell[i,5]=particle2cell_vertex(sys.mesh.cell_length,delta_r,5)/V_cell              
        sys.particle2cell[i,6]=particle2cell_vertex(sys.mesh.cell_length,delta_r,6)/V_cell          
        sys.particle2cell[i,7]=particle2cell_vertex(sys.mesh.cell_length,delta_r,7)/V_cell          
        sys.particle2cell[i,8]=particle2cell_vertex(sys.mesh.cell_length,delta_r,8)/V_cell
    end
end

function perparticle2density!(local_field::Array{Array{Float64,1}},types::Int64,cellindex::Array{Int64,2},particle2cell::Array{Float64,1},num_cells::Int64)
    for j in 1:8
        local_field[types][SerializeCellIndex(cellindex[j,1],cellindex[j,2],cellindex[j,3],num_cells)] += particle2cell[j]
    end
end

function particle2density!(sys::System)
    for i in 1:sys.local_N
        for j in 1:8
            sys.local_field[sys.types[i]][SerializeCellIndex(sys.cellindex[i][j,1],sys.cellindex[i][j,2],sys.cellindex[i][j,3],sys.mesh.num_cells)] += sys.particle2cell[i,j]
        end
    end 
end

function pbc_mesh(index::Int64,num_cells::Int64)
    if index>0
        return index-floor(Int64,index/(num_cells-1))*(num_cells-1)
    else
        return index-floor(Int64,index/(num_cells-1))*(num_cells-1)
    end
end

function update_particlecellindex!(coords::Array{Float64,1},cellindex::Array{Int64,2},cell_length::Float64,num_cells::Int64)
   
    cell_index_x=floor(coords[1] / cell_length) # 0 to num_cells-1, PBC: 0=num_cells-1
    cell_index_y=floor(coords[2] / cell_length) # 0 to num_cells-1, PBC: 0=num_cells-1
    cell_index_z=floor(coords[3] / cell_length) # 0 to num_cells-1, PBC: 0=num_cells-1

    cell_index_x=cell_index_x-floor(Int64,cell_index_x/((num_cells-1)))*(num_cells-1)
    cell_index_y=cell_index_y-floor(Int64,cell_index_y/((num_cells-1)))*(num_cells-1)
    cell_index_z=cell_index_z-floor(Int64,cell_index_z/((num_cells-1)))*(num_cells-1)

    cell_index_plus_x=cell_index_x +1-floor(Int64,(cell_index_x+1)/((num_cells-1)))*(num_cells-1)
    cell_index_plus_y=cell_index_y +1-floor(Int64,(cell_index_y+1)/((num_cells-1)))*(num_cells-1)
    cell_index_plus_z=cell_index_z +1-floor(Int64,(cell_index_z+1)/((num_cells-1)))*(num_cells-1)

    cell_index_x=cell_index_x+1
    cell_index_y=cell_index_y+1
    cell_index_z=cell_index_z+1
    cell_index_plus_x=cell_index_plus_x+1
    cell_index_plus_y=cell_index_plus_y+1
    cell_index_plus_z=cell_index_plus_z+1


    cellindex[1,1]=cell_index_x
    cellindex[1,2]=cell_index_y
    cellindex[1,3]=cell_index_z      

    cellindex[2,1]=cell_index_x   
    cellindex[2,2]=cell_index_plus_y
    cellindex[2,3]=cell_index_z           

    cellindex[3,1]=cell_index_x  
    cellindex[3,2]=cell_index_plus_y 
    cellindex[3,3]=cell_index_plus_z

    cellindex[4,1]=cell_index_x 
    cellindex[4,2]=cell_index_y
    cellindex[4,3]=cell_index_plus_z

    cellindex[5,1]=cell_index_plus_x 
    cellindex[5,2]=cell_index_y  
    cellindex[5,3]=cell_index_z   

    cellindex[6,1]=cell_index_plus_x
    cellindex[6,2]=cell_index_y 
    cellindex[6,3]=cell_index_plus_z   

    cellindex[7,1]=cell_index_plus_x
    cellindex[7,2]=cell_index_plus_y
    cellindex[7,3]=cell_index_z 

    cellindex[8,1]=cell_index_plus_x
    cellindex[8,2]=cell_index_plus_y
    cellindex[8,3]=cell_index_plus_z
end

function update_cellindex!(sys::System)
   
    cell_index=floor.(sys.coords ./ sys.mesh.cell_length) # 0 to num_cells-1, PBC: 0=num_cells-1
    @show cell_index
    cell_index=cell_index-floor.(Array{Int64,1},cell_index./((sys.mesh.num_cells-1)))*(sys.mesh.num_cells-1)
    cell_index_plus=cell_index.+1-floor.(Array{Int64,1},(cell_index.+1)./((sys.mesh.num_cells-1)))*(sys.mesh.num_cells-1)

    cell_index=cell_index.+1
    cell_index_plus=cell_index_plus.+1

    for i in 1:sys.local_N

        sys.cellindex[i][1,1]=cell_index[i,1]
        sys.cellindex[i][1,2]=cell_index[i,2]
        sys.cellindex[i][1,3]=cell_index[i,3]      

        sys.cellindex[i][2,1]=cell_index[i,1]   
        sys.cellindex[i][2,2]=cell_index_plus[i,2]
        sys.cellindex[i][2,3]=cell_index[i,3]           

        sys.cellindex[i][3,1]=cell_index[i,1]  
        sys.cellindex[i][3,2]=cell_index_plus[i,2] 
        sys.cellindex[i][3,3]=cell_index_plus[i,3]

        sys.cellindex[i][4,1]=cell_index[i,1] 
        sys.cellindex[i][4,2]=cell_index[i,2]
        sys.cellindex[i][4,3]=cell_index_plus[i,3]

        sys.cellindex[i][5,1]=cell_index_plus[i,1] 
        sys.cellindex[i][5,2]=cell_index[i,2]  
        sys.cellindex[i][5,3]=cell_index[i,3]   

        sys.cellindex[i][6,1]=cell_index_plus[i,1]
        sys.cellindex[i][6,2]=cell_index[i,2] 
        sys.cellindex[i][6,3]=cell_index_plus[i,3]   

        sys.cellindex[i][7,1]=cell_index_plus[i,1]
        sys.cellindex[i][7,2]=cell_index_plus[i,2]
        sys.cellindex[i][7,3]=cell_index[i,3] 

        sys.cellindex[i][8,1]=cell_index_plus[i,1]
        sys.cellindex[i][8,2]=cell_index_plus[i,2]
        sys.cellindex[i][8,3]=cell_index_plus[i,3]
    end
end

function grad_field_vertex!(coord_cell,global_field,field_gradient,num_cells)
    icell_plus=pbc_mesh(coord_cell[1]+1,num_cells)+1
    jcell_plus=pbc_mesh(coord_cell[2]+1,num_cells)+1
    kcell_plus=pbc_mesh(coord_cell[3]+1,num_cells)+1

    icell_minus=pbc_mesh(coord_cell[1]-1,num_cells)+1
    jcell_minus=pbc_mesh(coord_cell[2]-1,num_cells)+1
    kcell_minus=pbc_mesh(coord_cell[3]-1,num_cells)+1

    icell_=icell+1
    jcell_=jcell+1
    kcell_=kcell+1

    g_x=global_field[SerializeCellIndex(icell_plus,jcell_,kcell_,num_cells)]-sys.global_field[SerializeCellIndex(icell_minus,jcell_,kcell_,num_cells)]
    g_y=global_field[SerializeCellIndex(icell_,jcell_plus,kcell_,num_cells)]-sys.global_field[SerializeCellIndex(icell_,jcell_minus,kcell_,num_cells)]
    g_z=global_field[SerializeCellIndex(icell_,jcell_,kcell_plus,num_cells)]-sys.global_field[SerializeCellIndex(icell_,jcell_,kcell_minus,num_cells)]
    
    field_gradient[SerializeCellGradIndex(icell_,jcell_,kcell_,1,num_cells)] += 0.5*g_x
    field_gradient[SerializeCellGradIndex(icell_,jcell_,kcell_,2,num_cells)] += 0.5*g_y
    field_gradient[SerializeCellGradIndex(icell_,jcell_,kcell_,3,num_cells)] += 0.5*g_z
end

function grad_field!(sys::System)
    for i in 1:sys.num_atomtype
        grad_field_vertex!.(sys.mesh.mesh_index,Ref(sys.global_field[i]),Ref(sys.field_gradient[i]),sys.mesh.num_cells)
    end
end

function force_field_particle!(forces::Array{Float64,1},
                                types::Int64,
                                particle2cell::Array{Float64,1},
                                cellindex::Array{Int64,2},
                                num_atomtype::Int64,
                                num_cells::Int64,
                                field::Field,
                                field_gradient::Array{Array{Float64,1},1})
    sum_graident_field_x=0.0
    sum_graident_field_y=0.0
    sum_graident_field_z=0.0
    for atomtype in 1:num_atomtype
        field_gradient_x=0.0
        field_gradient_y=0.0
        field_gradient_z=0.0
        for j in 1:8
            field_gradient_x+=field_gradient[atomtype][SerializeCellGradIndex(cellindex[j,1],cellindex[j,2],cellindex[j,3],1,num_cells)] * particle2cell[j]
            field_gradient_y+=field_gradient[atomtype][SerializeCellGradIndex(cellindex[j,1],cellindex[j,2],cellindex[j,3],2,num_cells)] * particle2cell[j]
            field_gradient_z+=field_gradient[atomtype][SerializeCellGradIndex(cellindex[j,1],cellindex[j,2],cellindex[j,3],3,num_cells)] * particle2cell[j]
        end
        forces[1]+=-field.χ[types,atomtype]*field_gradient_x
        forces[2]+=-field.χ[types,atomtype]*field_gradient_y
        forces[3]+=-field.χ[types,atomtype]*field_gradient_z
        sum_graident_field_x+=field_gradient_x
        sum_graident_field_y+=field_gradient_y
        sum_graident_field_z+=field_gradient_z
    end
    forces[1] += -1.0/field.κ * sum_graident_field_x
    forces[2] += -1.0/field.κ * sum_graident_field_y
    forces[3] += -1.0/field.κ * sum_graident_field_z
end

function force_field!(sys::System,field::CanonicalField,comm::MPI.Comm)

    if sys.first_step[1] || sys.current_step[1] % field.τ==0
        clear_field!(sys)
        perparticle2cell!.(sys.coords,sys.particle2cell,sys.mesh.cell_length,sys.mesh.V_cell)
        update_particlecellindex!.(sys.coords,sys.cellindex,sys.mesh.cell_length,sys.mesh.num_cells)
        perparticle2density!.(Ref(sys.local_field),sys.types,sys.cellindex,sys.particle2cell,sys.mesh.num_cells)
        for i in 1:sys.num_atomtype
            MPI.Allreduce!(sys.local_field[i],sys.global_field[i],sum_mesh,comm)
        end
        grad_field!(sys)
    end

    #particle2cell!(sys)
    #update_cellindex!(sys)
    perparticle2cell!.(sys.coords,sys.particle2cell,sys.mesh.cell_length,sys.mesh.V_cell)
    update_particlecellindex!.(sys.coords,sys.cellindex,sys.mesh.cell_length,sys.mesh.num_cells)

    force_field_particle!.(sys.forces,sys.types,sys.particle2cell,sys.cellindex,sys.num_atomtype,sys.mesh.num_cells,sys.field,Ref(sys.field_gradient))
    #for i in 1:sys.local_N
    #    sum_graident_field=zeros(3)
    #    for atomtype in 1:sys.num_atomtype
    #        field_gradient=zeros(3)
    #        for j in 1:8
    #            field_gradient[1]+=sys.field_gradient[atomtype][SerializeCellGradIndex(sys.cellindex[i][j,1],sys.cellindex[i][j,2],sys.cellindex[i][j,3],1,sys.mesh.num_cells)] * sys.particle2cell[i,j]
    #            field_gradient[2]+=sys.field_gradient[atomtype][SerializeCellGradIndex(sys.cellindex[i][j,1],sys.cellindex[i][j,2],sys.cellindex[i][j,3],2,sys.mesh.num_cells)] * sys.particle2cell[i,j]
    #            field_gradient[3]+=sys.field_gradient[atomtype][SerializeCellGradIndex(sys.cellindex[i][j,1],sys.cellindex[i][j,2],sys.cellindex[i][j,3],3,sys.mesh.num_cells)] * sys.particle2cell[i,j]
    #        end
    #        forces[i,1]+=-field.χ[sys.types[i],atomtype].*field_gradient[1]
    #        forces[i,2]+=-field.χ[sys.types[i],atomtype].*field_gradient[2]
    #        forces[i,3]+=-field.χ[sys.types[i],atomtype].*field_gradient[3]
    #
    #        sum_graident_field.+=field_gradient
    #    end
    #    forces[i,1] += -1.0/field.κ * sum_graident_field[1]
    #    forces[i,2] += -1.0/field.κ * sum_graident_field[2]
    #    forces[i,3] += -1.0/field.κ * sum_graident_field[3]
    #end

end

