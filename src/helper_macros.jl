export @reshape_weights

macro reshape_weights(inputs...)
  ex=quote end
  offs_ex = 1
  fin_ex  = 0

  for i=1:length(inputs)
    scur=inputs[i].args[3]
    !isa(scur,Expr) && (scur=Expr(:tuple,scur))
    wsym=esc(inputs[i].args[2])
    winsym = esc(:w)
    mul_sizes = Expr(:call,:*,map(esc,scur.args)...)
    fin_ex=:($fin_ex + $mul_sizes)
    reshex = Expr(:call,:reshape,:(($winsym)[$(copy(offs_ex)):$fin_ex]),map(esc,scur.args)...)
    push!(ex.args,:($wsym = $reshex))
    offs_ex = :($offs_ex + $mul_sizes)
  end
  ex
end

#gemv!(tA, alpha, A, x, beta, y)
#Update the vector y as alpha*A*x + beta*y or alpha*A'x + beta*y according to tA (transpose A). Returns the updated y.
macro chain_matmulv_add(ex)
  ex.head==:(.=) || error("Wrong format. Input expression must be assignment with .=")
  outAr = esc(ex.args[1])
  ex = ex.args[2]
  (ex.head==:call && ex.args[1]==:(+)) || error("Wrong input format, right-hand side must be a sum")
  outEx = quote end
  for a in ex.args[2:end]
    if isa(a,Symbol)
      push!(outEx.args,:(vec_add!($outAr,$(esc(a)))))
    elseif a.head==:call && a.args[1]==:(*)
      matsym = a.args[2]
      t='N'
      if isa(matsym,Expr)
        t='T'
        matsym=esc(matsym.args[1])
      else
        matsym=esc(matsym)
      end
      vecsym = esc(a.args[3])
      push!(outEx.args,:(gemv!($t,1.0,$matsym,$vecsym,1.0,$outAr)))
    else
      error("Unknown operand")
    end
  end
  outEx
end

function f_allocate_dw(ex::Symbol)
    exOut = esc(Symbol(string("d",ex)))
    return :($exOut = [zeros(size($(esc(ex)))) for i=1:$(esc(:nSamp))])
end
macro allocate_dw(ex...)
    all(i->isa(i,Symbol),ex) || error("Need symbols as inputs")
    o = Expr(:block,map(f_allocate_dw,ex)...)
    o
end

#macroexpand(:(@chain_matmulv_add dOut.=w1*x+w2*y+w3'*z+w4))

"Adds vectors a and b and stores the result in a"
function vec_add!(a,b)
  length(a) == length(b) || error("Lengths of a and b differ")
  @inbounds for i=1:length(a)
    a[i]=a[i]+b[i]
  end
  a
end
