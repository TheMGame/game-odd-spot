const $=id=>document.getElementById(id);
const state={catalog:[],assets:[],view:"overview",series:null,level:null,levelEntry:null,selected:0,dirty:false,adding:false,puzzleSelected:-1,puzzleView:"mixed"};
const ADMIN_SESSION_KEY="oddspot_admin_session";
const ADMIN_SESSION_MS=30*24*60*60*1000;
function token(){
  try{
    const session=JSON.parse(localStorage.getItem(ADMIN_SESSION_KEY)||"null");
    if(session?.token&&Number(session.expires_at)>Date.now())return session.token;
  }catch(_){}
  localStorage.removeItem(ADMIN_SESSION_KEY);
  return "";
}
function saveAdminSession(value){
  localStorage.setItem(ADMIN_SESSION_KEY,JSON.stringify({token:value,expires_at:Date.now()+ADMIN_SESSION_MS}));
}
function clearAdminSession(){
  localStorage.removeItem(ADMIN_SESSION_KEY);
  sessionStorage.removeItem("oddspot_admin_token");
}
const apiBase=()=>localStorage.getItem("oddspot_admin_api")||`${location.origin}/admin/v1`;
const escapeHtml=value=>String(value??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const formatBytes=n=>n>1048576?`${(n/1048576).toFixed(1)} MB`:`${Math.ceil(n/1024)} KB`;

async function api(path,options={}){
  const response=await fetch(apiBase()+path,{...options,headers:{"X-Admin-Token":token(),...(options.headers||{})}});
  const body=await response.json().catch(()=>({}));
  if(!response.ok)throw new Error(body.message||body.error_code||`HTTP ${response.status}`);
  return body.data;
}
function toast(message,type=""){const el=$("toast");el.textContent=message;el.style.background=type==="error"?"#b42318":"#252b31";el.style.display="block";setTimeout(()=>el.style.display="none",2600)}
function setSave(text,dirty=false){state.dirty=dirty;$("save-state").textContent=text}
async function loadData(){const [catalog,assets]=await Promise.all([api("/catalog"),api("/assets")]);state.catalog=catalog.series||[];state.assets=assets.items||[]}

function shell(view,title){state.view=view;document.querySelectorAll(".nav-item").forEach(x=>x.classList.toggle("active",x.dataset.view===view));$("breadcrumb").textContent=`工作台 / ${title}`}
function renderOverview(){
  shell("overview","总览");const levels=state.catalog.flatMap(s=>s.levels||[]);
  $("view").innerHTML=`<div class="page"><div class="page-header"><div><h1>Studio Overview</h1><p>内容生产与发布状态一览</p></div><button class="btn primary" onclick="newLevel()">＋ 新建关卡</button></div>
  <div class="stats"><div class="stat"><label>已发布系列</label><strong>${state.catalog.filter(s=>s.enabled).length}</strong><span class="trend">后台动态配置</span></div><div class="stat"><label>已发布关卡</label><strong>${levels.length}</strong><span class="trend">客户端实时拉取</span></div><div class="stat"><label>素材文件</label><strong>${state.assets.length}</strong><span class="trend">${formatBytes(state.assets.reduce((a,b)=>a+b.bytes,0))}</span></div><div class="stat"><label>待审核</label><strong>0</strong><span class="trend">当前无阻塞</span></div></div>
  <div class="dashboard-grid"><section class="card"><h2>关卡生产趋势</h2><div class="chart">${[34,51,42,67,58,81,74].map(h=>`<div class="bar" style="height:${h}%"></div>`).join("")}</div></section><section class="card"><h2>快捷操作</h2><div class="quick-grid"><button class="quick" onclick="showSeriesModal()">新建内容系列 <span>›</span></button><button class="quick" onclick="newLevel()">新建关卡 <span>›</span></button><button class="quick" onclick="navigate('library')">上传素材 <span>›</span></button></div></section></div>
  <section class="card" style="margin-top:16px"><h2>最近内容</h2>${levelTable(levels.slice(0,6))}</section></div>`;
}
const LEVEL_STATUS_LABELS={published:"已发布",disabled:"已下架",draft:"草稿",generated:"已生成",pending_review:"待审核",auto_review_failed:"审核未过",approved:"已通过",staging:"预备"};
function levelStatusLabel(s){return LEVEL_STATUS_LABELS[s]||s||"草稿"}
function levelTable(levels,series){
  if(!levels.length)return`<div class="empty">暂无关卡</div>`;
  return `<table class="level-table"><thead><tr><th>预览</th><th>关卡</th><th>玩法</th><th>内容数</th><th>难度</th><th>版本</th><th>状态</th><th></th></tr></thead><tbody>${levels.map(l=>{const sid=series?.id||findSeries(l.id)?.id||"";return `<tr><td><img class="thumb" src="${escapeHtml(l.thumbnail_url)}"></td><td><b>${escapeHtml(l.title)}</b><br><small>${escapeHtml(l.id)}</small></td><td>${l.mode==="image_puzzle"?"拼图":"找穿帮"}</td><td>${l.content_count??l.difference_count??0}</td><td>${"◆".repeat(l.difficulty||1)}</td><td>v${l.version}</td><td><span class="badge ${l.status==="published"?"published":"draft"}">${levelStatusLabel(l.status)}</span></td><td style="white-space:nowrap"><div style="display:flex;gap:6px;justify-content:flex-end"><button class="btn small" onclick="openEditorById('${l.id}','${sid}')">编辑</button>${l.status==="published"?`<button class="btn small" onclick="setLevelStatus('${l.id}','disabled')">下架</button>`:""}${l.status==="disabled"?`<button class="btn small" onclick="setLevelStatus('${l.id}','published')">上架</button>`:""}${l.status!=="published"?`<button class="btn small danger" onclick="deleteLevelById('${l.id}')">删除</button>`:""}</div></td></tr>`}).join("")}</tbody></table>`;
}
function rerenderAfterCatalogChange(){if(state.view==="levels")return renderLevels();if(state.view==="overview")return renderOverview();if(state.series)return openSeries(state.series.id);renderSeries()}
async function setLevelStatus(id,status){const verb=status==="published"?"上架":"下架";if(!confirm(`确定${verb}关卡「${id}」吗？${status==="disabled"?"下架后玩家将无法看到该关卡。":""}`))return;try{await api(`/levels/${encodeURIComponent(id)}/status`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({status})});await loadData();rerenderAfterCatalogChange();toast(`已${verb}`)}catch(e){toast(e.message,"error")}}
async function deleteLevelById(id){const l=state.catalog.flatMap(s=>s.levels||[]).find(x=>x.id===id),name=l?.title||id;if(!confirm(`确定永久删除关卡「${name}」（${id}）吗？\n该操作会一并删除其版本与游玩记录，且不可恢复。`))return;try{await api(`/levels/${encodeURIComponent(id)}`,{method:"DELETE"});await loadData();rerenderAfterCatalogChange();toast("关卡已删除")}catch(e){toast(e.message,"error")}}
function renderSeries(){
  shell("series","内容系列");$("view").innerHTML=`<div class="page"><div class="page-header"><div><h1>内容系列</h1><p>管理所有游戏模式与系列内容</p></div><button class="btn primary" onclick="showSeriesModal()">＋ 新建系列</button></div><div class="filters"><input id="series-search" placeholder="搜索系列名称或 ID" oninput="filterSeries(this.value)"><select><option>全部状态</option><option>已启用</option><option>已停用</option></select></div><div id="series-list" class="series-list">${seriesRows(state.catalog)}</div></div>`;
}
function seriesRows(items){return items.map(s=>{const cover=s.cover_url||(s.levels?.[0]?.thumbnail_url||"");return`<article class="series-row" draggable="${s.id!=="daily_task"}" data-id="${s.id}" data-search="${escapeHtml((s.title+" "+s.id).toLowerCase())}" ondragstart="seriesDragStart(event)" ondragover="seriesDragOver(event)" ondrop="seriesDrop(event)"><span class="drag-handle" title="拖动排序">${s.id==="daily_task"?"◆":"⋮⋮"}</span><img class="series-cover" src="${escapeHtml(cover)}"><div><h3>${escapeHtml(s.title)} <span class="badge ${s.enabled?"published":"draft"}">${s.enabled?"ACTIVE":"DISABLED"}</span></h3><div class="meta"><span>${s.levels?.length||0} 个关卡</span><span>排序 ${s.sort_order??0}</span><span>${escapeHtml(s.description||"暂无说明")}</span></div></div><div class="actions"><button class="btn small" onclick="openSeries('${s.id}')">查看关卡</button><button class="btn small" onclick="showSeriesModal('${s.id}')">编辑系列</button></div></article>`}).join("")||`<div class="empty">还没有系列，创建第一个系列吧</div>`}
let draggedSeriesId="";
function seriesDragStart(event){draggedSeriesId=event.currentTarget.dataset.id;event.dataTransfer.effectAllowed="move"}
function seriesDragOver(event){if(event.currentTarget.dataset.id!=="daily_task"){event.preventDefault();event.dataTransfer.dropEffect="move"}}
async function seriesDrop(event){event.preventDefault();const targetId=event.currentTarget.dataset.id;if(!draggedSeriesId||draggedSeriesId===targetId||targetId==="daily_task")return;const movable=state.catalog.filter(s=>s.id!=="daily_task"),from=movable.findIndex(s=>s.id===draggedSeriesId),to=movable.findIndex(s=>s.id===targetId);if(from<0||to<0)return;const [moved]=movable.splice(from,1);movable.splice(to,0,moved);const daily=state.catalog.find(s=>s.id==="daily_task");state.catalog=daily?[...movable,daily]:movable;renderSeries();try{for(let i=0;i<movable.length;i++){const s=movable[i];await api("/series",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({id:s.id,title:s.title,description:s.description,mode:s.mode,cover_url:s.cover_url,sort_order:(i+1)*10,enabled:s.enabled})})}await loadData();renderSeries();toast("系列顺序已保存，游戏端将保持一致")}catch(e){toast(e.message,"error");await loadData();renderSeries()}}
function filterSeries(value){document.querySelectorAll(".series-row").forEach(x=>x.hidden=!x.dataset.search.includes(value.toLowerCase()))}
function openSeries(id){const s=state.catalog.find(x=>x.id===id);state.series=s;shell("series",s.title);$("view").innerHTML=`<div class="page"><div class="page-header"><div><button class="btn ghost" onclick="renderSeries()">← 返回系列</button><h1>${escapeHtml(s.title)}</h1><p>${escapeHtml(s.description)}</p></div><div class="actions"><button class="btn" onclick="showSeriesModal('${s.id}')">编辑系列</button><button class="btn primary" onclick="newLevel('${s.id}')">＋ 新建关卡</button></div></div><section class="card">${levelTable(s.levels||[],s)}</section></div>`}
function renderLevels(){shell("levels","关卡管理");$("view").innerHTML=`<div class="page"><div class="page-header"><div><h1>关卡管理</h1><p>跨系列查看与编辑全部关卡</p></div><button class="btn primary" onclick="newLevel()">＋ 新建关卡</button></div>${levelTable(state.catalog.flatMap(s=>s.levels||[]))}</div>`}
function renderLibrary(){
  shell("library","素材库");$("view").innerHTML=`<div class="page"><div class="page-header"><div><h1>素材库</h1><p>列表加载轻量缩略图，进入关卡后才加载原图</p></div><button class="btn primary" onclick="$('asset-file').click()">上传素材</button></div><div class="dropzone" onclick="$('asset-file').click()"><b>拖放或点击上传图片</b><p>PNG、JPG，最大 15 MB；上传后自动生成缩略图</p><input id="asset-file" type="file" accept="image/png,image/jpeg" hidden onchange="uploadLibraryAsset(this.files[0])"></div><div class="library-grid">${state.assets.map(a=>`<article class="asset-card"><img src="${escapeHtml(a.thumbnail_url||a.url)}" loading="lazy"><div class="asset-info"><b>${escapeHtml(a.name)}</b><small>原图 ${formatBytes(a.bytes)}${a.thumbnail_bytes?` · 缩略图 ${formatBytes(a.thumbnail_bytes)}`:""}</small><div style="margin-top:8px"><button class="btn small" onclick="navigator.clipboard.writeText('${escapeHtml(a.url)}');toast('原图 URL 已复制')">复制原图 URL</button></div></div></article>`).join("")}</div></div>`;
}
function renderPlaceholder(view,title,description){shell(view,title);$("view").innerHTML=`<div class="page"><div class="page-header"><div><h1>${title}</h1><p>${description}</p></div></div><div class="card empty">该模块已纳入 Studio 导航，将在对应数据接口完成后接入。</div></div>`}
function navigate(view){if(state.dirty&&!confirm("当前关卡有未保存修改，确定离开吗？"))return;({overview:renderOverview,series:renderSeries,levels:renderLevels,library:renderLibrary,review:()=>renderReview(),feedback:()=>renderPlaceholder("feedback","问题反馈","集中处理玩家上报的问题"),analytics:()=>renderPlaceholder("analytics","数据分析","查看完成率、提示使用与热点误触"),settings:()=>renderSettings()})[view]()}
function findSeries(levelId){return state.catalog.find(s=>(s.levels||[]).some(l=>l.id===levelId))}

async function openEditorById(levelId,seriesId){
  try{const data=await api(`/levels/${encodeURIComponent(levelId)}`);state.level=structuredClone(data);state.series=state.catalog.find(s=>s.id===seriesId)||findSeries(levelId);state.levelEntry=state.series?.levels.find(l=>l.id===levelId);state.selected=0;state.dirty=false;renderEditor()}catch(e){toast(e.message,"error")}
}
function renderEditor(){
  const l=state.level,diffs=l.differences||[],asset=l.assets?.image||{};shell("levels",`关卡编辑器 / ${l.title}`);
  if(l.mode==="image_puzzle")return renderPuzzleEditor();
  $("view").innerHTML=`<div class="editor"><aside class="editor-left"><div class="editor-head"><h2>${escapeHtml(l.title)}</h2><small>${escapeHtml(l.level_id)} · v${l.level_version}</small></div><div class="panel-section"><div class="panel-title">关卡信息</div><div class="form-stack"><label>标题<input id="level-title" value="${escapeHtml(l.title)}" oninput="updateLevelField('title',this.value)"></label><label>玩法<select onchange="changeLevelMode(this.value)"><option value="find_anachronism" selected>找穿帮</option><option value="image_puzzle">拼图（错位还原）</option></select></label><label>所属系列<select id="editor-series" onchange="markDirty()">${state.catalog.map(s=>`<option value="${s.id}" ${s.id===state.series?.id?"selected":""}>${escapeHtml(s.title)}</option>`).join("")}</select></label><label>难度<select id="level-difficulty" onchange="updateDifficulty(this.value)">${[1,2,3,4,5].map(n=>`<option ${n===(l.difficulty?.total||1)?"selected":""}>${n}</option>`).join("")}</select></label></div></div><div class="panel-section"><div class="panel-title">答案热点 ${diffs.length}</div><div id="answer-list" class="answer-list">${answerList()}</div><button class="btn small" style="width:100%;margin-top:10px" onclick="addAnswer()">＋ 添加答案</button></div></aside>
  <section class="canvas-pane"><div class="canvas-toolbar"><div class="canvas-tools"><button class="btn small" onclick="state.adding=!state.adding;this.classList.toggle('primary',state.adding)">⌖ 标注工具</button><button class="btn small" onclick="toggleSafeZones()">安全区域</button><button class="btn small" onclick="fitImage()">适应窗口</button></div><span>${l.assets?.width||0} × ${l.assets?.height||0}</span></div><div class="canvas-workspace"><div id="image-stage" class="image-stage" onclick="canvasClick(event)"><img id="level-image" src="${escapeHtml(asset.url||asset.local_path||"")}" draggable="false">${hotspots()}<div class="safe-zone"></div><div class="safe-zone bottom"></div></div></div><footer class="editor-footer"><span id="editor-status">自动保存未启用 · 请手动保存</span><div class="actions"><button class="btn" onclick="showMobilePreview()">手机预览</button><button class="btn" onclick="saveLevel('draft')">保存草稿</button><button class="btn primary" onclick="showPublishModal()">发布关卡</button></div></footer></section><aside class="inspector" id="inspector">${inspector()}</aside></div>`;
  bindHotspotDrag();
}
function renderPuzzleEditor(){
  const l=state.level,p=l.puzzle||(l.puzzle={rows:5,cols:4}),asset=l.assets?.image||{};
  $("view").innerHTML=`<div class="editor"><aside class="editor-left"><div class="editor-head"><h2>${escapeHtml(l.title)}</h2><small>${escapeHtml(l.level_id)} · v${l.level_version}</small></div><div class="panel-section"><div class="panel-title">关卡信息</div><div class="form-stack"><label>标题<input value="${escapeHtml(l.title)}" oninput="updateLevelField('title',this.value)"></label><label>玩法<select onchange="changeLevelMode(this.value)"><option value="find_anachronism">找穿帮</option><option value="image_puzzle" selected>拼图（错位还原）</option></select></label><label>所属系列<select id="editor-series" onchange="markDirty()">${state.catalog.map(s=>`<option value="${s.id}" ${s.id===state.series?.id?"selected":""}>${escapeHtml(s.title)}</option>`).join("")}</select></label><label>难度<select id="level-difficulty" onchange="updateDifficulty(this.value)">${[1,2,3,4,5].map(n=>`<option ${n===(l.difficulty?.total||1)?"selected":""}>${n}</option>`).join("")}</select></label></div></div><div class="panel-section"><div class="panel-title">拼图设置</div><div class="coord-grid"><label>行<input type="number" min="2" max="8" value="${p.rows}" onchange="updatePuzzleGrid('rows',this.value)"></label><label>列<input type="number" min="2" max="8" value="${p.cols}" onchange="updatePuzzleGrid('cols',this.value)"></label></div><p>共 ${p.rows*p.cols} 块 · 玩家每次开局都会随机打乱（每块都不在原位）</p></div></aside><section class="canvas-pane"><div class="canvas-toolbar"><div class="canvas-tools"><span>分割预览</span></div><span>${l.assets?.width||0} × ${l.assets?.height||0}</span></div><div class="canvas-workspace"><canvas id="puzzle-admin-canvas" class="puzzle-admin-canvas" data-src="${escapeHtml(asset.url||asset.local_path||"")}"></canvas></div><footer class="editor-footer"><span id="editor-status">调整行列即可，打乱由客户端随机生成</span><div class="actions"><button class="btn" onclick="showMobilePreview()">手机预览</button><button class="btn" onclick="saveLevel('draft')">保存草稿</button><button class="btn primary" onclick="showPublishModal()">发布关卡</button></div></footer></section><aside class="inspector" id="inspector"><div class="panel-section"><h2>拼图说明</h2><p>管理端只需设置分割的行数与列数。玩家每次进入或重玩时，客户端会随机打乱所有拼块并保证每一块都不在正确位置，完成后记录用时。</p></div></aside></div>`;
  drawPuzzleAdmin();
}
function changeLevelMode(mode){if(mode===state.level.mode)return;if(!confirm("切换玩法会重置当前玩法配置，是否继续？")){renderEditor();return}if(mode==="image_puzzle"){delete state.level.differences;state.level.puzzle={rows:5,cols:4};state.level.instruction="随机打乱拼块，还原完整画面"}else{delete state.level.puzzle;state.level.differences=[];state.level.instruction="圈出不属于这个年代的物件"}state.level.mode=mode;state.puzzleSelected=-1;markDirty();renderEditor()}
function drawPuzzleAdmin(){const canvas=$("puzzle-admin-canvas");if(!canvas)return;const img=new Image();img.crossOrigin="anonymous";img.onload=()=>{const p=state.level.puzzle,maxW=760,maxH=Math.max(400,innerHeight-180),scale=Math.min(maxW/img.naturalWidth,maxH/img.naturalHeight,1);canvas.width=Math.round(img.naturalWidth*scale);canvas.height=Math.round(img.naturalHeight*scale);const ctx=canvas.getContext("2d"),dw=canvas.width/p.cols,dh=canvas.height/p.rows;ctx.drawImage(img,0,0,canvas.width,canvas.height);ctx.lineWidth=1.5;for(let cell=0;cell<p.rows*p.cols;cell++){const dc=cell%p.cols,dr=Math.floor(cell/p.cols);ctx.strokeStyle="#ffffffcc";ctx.strokeRect(dc*dw,dr*dh,dw,dh);ctx.fillStyle="#111c";ctx.font="bold 13px sans-serif";ctx.fillText(String(cell+1).padStart(2,"0"),dc*dw+7,dr*dh+18)}};img.src=canvas.dataset.src}
function updatePuzzleGrid(key,value){const p=state.level.puzzle,next=Math.max(2,Math.min(8,Number(value)||2));p[key]=next;if(p.rows*p.cols>48){p[key]=key==="rows"?Math.floor(48/p.cols):Math.floor(48/p.rows);toast("网格最多 48 格","error")}markDirty();renderEditor()}
function answerList(){return(state.level.differences||[]).map((d,i)=>`<div class="answer-item ${i===state.selected?"active":""}" onclick="selectAnswer(${i})"><span class="answer-number">${i+1}</span><div><b>${escapeHtml(d.label||d.id||"未命名答案")}</b><br><small>${escapeHtml(d.era||"未填写线索")}</small></div></div>`).join("")}
function hotspots(){return(state.level.differences||[]).map((d,i)=>{const radius=Math.max(3,(d.radius||.04)*100);return`<button class="hotspot ${i===state.selected?"selected":""}" data-index="${i}" style="left:${d.x*100}%;top:${d.y*100}%;width:${radius*2}%;aspect-ratio:1">${i+1}</button>`}).join("")}
function inspector(){const d=state.level.differences?.[state.selected];if(!d)return`<div class="empty">选择或添加一个答案热点</div>`;return`<div class="editor-head"><h2>热点属性</h2><small>${escapeHtml(d.id)}</small></div><div class="panel-section"><div class="panel-title">答案内容</div><div class="form-stack"><label>显示名称<input value="${escapeHtml(d.label||"")}" oninput="updateDiff('label',this.value)"></label><label>物品 ID<input value="${escapeHtml(d.id||"")}" oninput="updateDiff('id',this.value)"></label><label>线索<input value="${escapeHtml(d.era||"")}" placeholder="如：多年后才出现 / 20世纪后期普及" oninput="updateDiff('era',this.value)"></label><label>线索推理<textarea placeholder="说明技术、材料或使用场景为何矛盾，尽量给出可学习的知识依据" oninput="updateDiff('explanation',this.value)">${escapeHtml(d.explanation||"")}</textarea></label><label>答案难度<select onchange="updateDiff('difficulty',Number(this.value))">${[1,2,3,4,5].map(n=>`<option ${n===(d.difficulty||1)?"selected":""}>${n}</option>`).join("")}</select></label></div></div><div class="panel-section"><div class="panel-title">坐标与容错</div><div class="coord-grid"><label>X<input type="number" step=".001" value="${d.x}" onchange="updateDiff('x',Number(this.value),true)"></label><label>Y<input type="number" step=".001" value="${d.y}" onchange="updateDiff('y',Number(this.value),true)"></label><label>半径<input type="number" step=".005" value="${d.radius||.04}" onchange="updateDiff('radius',Number(this.value),true)"></label></div></div><div class="panel-section"><button class="btn danger" style="width:100%" onclick="removeAnswer()">删除热点</button></div>`}
function selectAnswer(i){state.selected=i;document.querySelectorAll(".answer-item").forEach((x,n)=>x.classList.toggle("active",n===i));document.querySelectorAll(".hotspot").forEach((x,n)=>x.classList.toggle("selected",n===i));$("inspector").innerHTML=inspector()}
function updateLevelField(key,value){state.level[key]=value;markDirty()}
function updateDifficulty(value){state.level.difficulty=state.level.difficulty||{};state.level.difficulty.total=Number(value);markDirty()}
function updateDiff(key,value,rerender=false){state.level.differences[state.selected][key]=value;markDirty();if(rerender)renderEditor();else document.querySelectorAll(".answer-item")[state.selected].querySelector("b").textContent=state.level.differences[state.selected].label||state.level.differences[state.selected].id}
function markDirty(){setSave("有未保存修改",true);const status=$("editor-status");if(status)status.textContent="● 有未保存修改"}
function addAnswer(){const diffs=state.level.differences||(state.level.differences=[]);diffs.push({id:`answer_${diffs.length+1}`,shape:"circle",x:.5,y:.5,radius:.04,label:"新答案",era:"",explanation:"",difficulty:1,operation:"anachronism"});state.selected=diffs.length-1;markDirty();renderEditor();state.adding=true}
function removeAnswer(){if(!confirm("确定删除这个答案热点吗？"))return;state.level.differences.splice(state.selected,1);state.selected=Math.max(0,state.selected-1);markDirty();renderEditor()}
function canvasClick(event){if(!state.adding||event.target.classList.contains("hotspot"))return;const rect=$("level-image").getBoundingClientRect();if(event.clientX<rect.left||event.clientX>rect.right||event.clientY<rect.top||event.clientY>rect.bottom)return;const d=state.level.differences[state.selected];d.x=+(Math.max(0,Math.min(1,(event.clientX-rect.left)/rect.width))).toFixed(4);d.y=+(Math.max(0,Math.min(1,(event.clientY-rect.top)/rect.height))).toFixed(4);state.adding=false;markDirty();renderEditor()}
function bindHotspotDrag(){document.querySelectorAll(".hotspot").forEach(el=>el.onpointerdown=e=>{e.stopPropagation();const i=Number(el.dataset.index);selectAnswer(i);el.setPointerCapture(e.pointerId);el.onpointermove=move=>{const rect=$("level-image").getBoundingClientRect(),d=state.level.differences[i];d.x=Math.max(0,Math.min(1,(move.clientX-rect.left)/rect.width));d.y=Math.max(0,Math.min(1,(move.clientY-rect.top)/rect.height));el.style.left=`${d.x*100}%`;el.style.top=`${d.y*100}%`;markDirty()};el.onpointerup=()=>{el.onpointermove=null;$("inspector").innerHTML=inspector()}})}
function toggleSafeZones(){document.querySelectorAll(".safe-zone").forEach(x=>x.hidden=!x.hidden)}
function fitImage(){$("level-image").style.maxHeight="calc(100vh - 160px)"}

async function saveLevel(status){
  try{if(status==="published"&&state.level.mode==="find_anachronism"){const incomplete=state.level.differences.find(x=>!String(x.era||"").trim()||String(x.explanation||"").trim().length<20);if(incomplete)throw new Error(`答案“${incomplete.label||incomplete.id}”需要填写线索和至少20字的线索推理`)}setSave("保存中…");state.level.instruction=`圈出 ${state.level.differences.length} 个不属于这个年代的物件`;state.level.level_version=Number(state.level.level_version||1)+1;const seriesId=$("editor-series")?.value||state.series.id;await api(`/levels/${encodeURIComponent(state.level.level_id)}`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({series_id:seriesId,sort_order:state.levelEntry?.sort_order||10,status,runtime_json:state.level})});setSave("已保存",false);toast(status==="published"?"关卡已发布":"草稿已保存");await loadData();state.series=state.catalog.find(s=>s.id===seriesId);state.levelEntry=state.series?.levels.find(l=>l.id===state.level.level_id);renderEditor()}catch(e){setSave("保存失败",true);toast(e.message,"error")}}
function showPublishModal(){const l=state.level,d=l.differences||[],valid=d.every(x=>x.id&&x.label&&x.era&&String(x.explanation||"").trim().length>=20&&x.x>=0&&x.x<=1&&x.y>=0&&x.y<=1);$("modal-root").innerHTML=`<div class="modal-backdrop"><div class="modal"><div class="modal-header"><h2>发布关卡</h2><button class="btn ghost" onclick="closeModal()">✕</button></div><div class="modal-body"><p><b>${escapeHtml(l.title)}</b> · v${Number(l.level_version)+1}</p><div class="checks"><div class="check">✓ 图片资源已配置</div><div class="check">✓ 图片比例 ${l.assets.width}:${l.assets.height}</div><div class="check">✓ ${d.length} 个答案热点</div><div class="check">${valid?"✓":"⚠"} 答案名称、线索、推理与坐标校验（推理至少20字）</div></div><label style="display:grid;gap:6px;margin-top:16px">变更摘要<textarea id="publish-note" placeholder="说明本次修改内容"></textarea></label></div><div class="modal-footer"><button class="btn" onclick="closeModal()">取消</button><button class="btn primary" ${valid?"":"disabled"} onclick="closeModal();saveLevel('published')">确认并发布</button></div></div></div>`}
function showMobilePreview(){const a=state.level.assets.image;$("modal-root").innerHTML=`<div class="modal-backdrop"><div class="modal"><div class="modal-header"><h2>手机玩家预览</h2><button class="btn ghost" onclick="closeModal()">✕</button></div><div class="modal-body"><div class="mobile-preview"><div class="mobile-top"><span>‹</span><b>${escapeHtml(state.level.title)}</b><span>💡</span></div><div style="position:relative"><img src="${escapeHtml(a.url||a.local_path)}">${hotspots()}</div></div></div></div></div>`}
function closeModal(){$("modal-root").innerHTML=""}

function showSeriesModal(id=""){const s=state.catalog.find(x=>x.id===id)||{id:"",title:"",description:"",cover_url:"",sort_order:10,enabled:true};$("modal-root").innerHTML=`<div class="modal-backdrop"><form class="modal" onsubmit="saveSeries(event)"><div class="modal-header"><h2>${id?"编辑":"新建"}系列</h2><button type="button" class="btn ghost" onclick="closeModal()">✕</button></div><div class="modal-body form-stack"><label>系列 ID<input id="series-id" value="${escapeHtml(s.id)}" ${id?"readonly":""} required></label><label>系列名称<input id="series-title" value="${escapeHtml(s.title)}" required></label><label>说明<textarea id="series-description">${escapeHtml(s.description)}</textarea></label><label>封面 URL<input id="series-cover" value="${escapeHtml(s.cover_url)}"></label><label><input id="series-enabled" type="checkbox" ${s.enabled?"checked":""}> 启用系列</label></div><div class="modal-footer"><button type="button" class="btn" onclick="closeModal()">取消</button><button class="btn primary">保存系列</button></div></form></div>`}
async function saveSeries(event){event.preventDefault();const existing=state.catalog.find(x=>x.id===$("series-id").value);const nextOrder=Math.max(0,...state.catalog.filter(x=>x.id!=="daily_task").map(x=>Number(x.sort_order)||0))+10;try{await api("/series",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({id:$("series-id").value,title:$("series-title").value,description:$("series-description").value,cover_url:$("series-cover").value,sort_order:existing?.sort_order??nextOrder,enabled:$("series-enabled").checked})});closeModal();await loadData();renderSeries();toast("系列已保存")}catch(e){toast(e.message,"error")}}
function newLevel(seriesId=""){const series=state.catalog.find(s=>s.id===seriesId)||state.catalog[0];if(!series)return showSeriesModal();state.series=series;state.levelEntry={sort_order:(series.levels?.length||0)*10+10};state.level={schema_version:1,level_id:`level_${Date.now()}`,level_version:1,mode:"find_anachronism",title:"未命名关卡",instruction:"圈出不属于这个年代的物件",assets:{image:{asset_id:"",url:"",sha256:"",bytes:0,content_type:"image/png"},width:1024,height:1536},differences:[],tags:{},difficulty:{total:1}};state.selected=0;renderEditor()}
async function uploadLibraryAsset(file){if(!file)return;try{const id=`asset_${Date.now()}`,asset=await api(`/assets/${id}`,{method:"POST",headers:{"Content-Type":file.type},body:file});toast("素材上传成功");await loadData();renderLibrary();return asset}catch(e){toast(e.message,"error")}}
function renderReview(){shell("review","审核中心");const levels=state.catalog.flatMap(s=>s.levels||[]);$("view").innerHTML=`<div class="page"><div class="page-header"><div><h1>审核中心</h1><p>检查图片、热点位置与历史解释</p></div></div>${levelTable(levels)}</div>`}
function renderSettings(){shell("settings","系统设置");const wm=getWatermarkConfig();$("view").innerHTML=`<div class="page"><div class="page-header"><div><h1>系统设置</h1><p>环境与 API 连接</p></div></div>
<section class="card form-stack" style="max-width:600px"><h3 style="margin:0 0 4px">连接配置</h3><label>Admin API<input id="settings-api" value="${escapeHtml(apiBase())}"></label><label>生产客户端 API<input value="在 client/project.godot 配置 oddspot/network/production_base_url" readonly></label><button class="btn primary" onclick="localStorage.setItem('oddspot_admin_api',$('settings-api').value);toast('设置已保存')">保存设置</button></section>
<section class="card form-stack" style="max-width:820px;margin-top:20px">
<h3 style="margin:0 0 4px">微信小游戏图片水印（AI 生成声明）</h3>
<p style="margin:0 0 14px;color:#68717d">开启后，微信版本所有游戏图片上显示水印文字（默认右上角标签），用于合规声明 AI 生成内容。配置修改后需同步到 <code>wechat/js/config.js</code> 的 WATERMARK 对象中。</p>
<label><input id="wm-enabled" type="checkbox" ${wm.enabled?"checked":""} onchange="saveWatermarkConfig()"> 启用水印功能</label>
<label>水印文字<input id="wm-text" value="${escapeHtml(wm.text)}" oninput="saveWatermarkConfig()" placeholder="内容由 AI 生成"></label>
<div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px">
<label>水印模式<select id="wm-mode" onchange="saveWatermarkConfig()">
<option value="corner" ${wm.mode==="corner"?"selected":""}>角落标签（推荐）</option>
<option value="tile" ${wm.mode==="tile"?"selected":""}>全屏斜向平铺</option>
</select></label>
<label>标签位置<select id="wm-placement" onchange="saveWatermarkConfig()">
<option value="top-right" ${wm.placement==="top-right"?"selected":""}>右上角</option>
<option value="top-left" ${wm.placement==="top-left"?"selected":""}>左上角</option>
<option value="bottom-right" ${wm.placement==="bottom-right"?"selected":""}>右下角</option>
<option value="bottom-left" ${wm.placement==="bottom-left"?"selected":""}>左下角</option>
<option value="four-corners" ${wm.placement==="four-corners"?"selected":""}>四角同显</option>
</select></label>
<label>字号（px）<input id="wm-size" type="number" min="10" max="80" value="${wm.size}" oninput="saveWatermarkConfig()"></label>
</div>
<div id="wm-corner-options" style="display:${wm.mode==="corner"?"grid":"none"};grid-template-columns:1fr 1fr 1fr;gap:10px;margin-top:2px">
<label>边距（px）<input id="wm-margin" type="number" min="0" max="200" value="${wm.margin}" oninput="saveWatermarkConfig()"></label>
<label>内边距 X<input id="wm-px" type="number" min="0" max="120" value="${wm.px}" oninput="saveWatermarkConfig()"></label>
<label>内边距 Y<input id="wm-py" type="number" min="0" max="120" value="${wm.py}" oninput="saveWatermarkConfig()"></label>
<label>圆角（px）<input id="wm-radius" type="number" min="0" max="60" value="${wm.radius}" oninput="saveWatermarkConfig()"></label>
<label>文字颜色<input id="wm-color" type="color" value="${wm.color}" oninput="saveWatermarkConfig()"> <small style="color:#68717d">纯色</small></label>
<label>不透明度<input id="wm-opacity" type="range" min="10" max="100" value="${wm.opacity}" oninput="saveWatermarkConfig()"><small id="wm-opacity-label">${wm.opacity}%</small></label>
<label>背景色<input id="wm-bgcolor" type="color" value="${wm.bgcolor}" oninput="saveWatermarkConfig()"> <small style="color:#68717d">纯色</small></label>
<label>背景不透明度<input id="wm-bgopacity" type="range" min="0" max="100" value="${wm.bgopacity}" oninput="saveWatermarkConfig()"><small id="wm-bgopacity-label">${wm.bgopacity}%</small></label>
<label>描边色<input id="wm-bordercolor" type="color" value="${wm.bordercolor}" oninput="saveWatermarkConfig()"> <small style="color:#68717d">纯色</small></label>
</div>
<div id="wm-tile-options" style="display:${wm.mode==="tile"?"grid":"none"};grid-template-columns:1fr 1fr;gap:10px;margin-top:2px">
<label>倾斜角度（度）<input id="wm-angle" type="number" min="-90" max="90" value="${wm.angle}" oninput="saveWatermarkConfig()"></label>
<label>横向间距（px）<input id="wm-mx" type="number" min="0" max="500" value="${wm.mx}" oninput="saveWatermarkConfig()"></label>
<label>纵向间距（px）<input id="wm-my" type="number" min="0" max="500" value="${wm.my}" oninput="saveWatermarkConfig()"></label>
<label>文字颜色<input id="wm-tile-color" type="color" value="${wm.tileColor||wm.color}" oninput="saveWatermarkConfig()"><small style="color:#68717d">纯色</small></label>
<label>平铺不透明度<input id="wm-tile-opacity" type="range" min="5" max="100" value="${wm.tileOpacity||wm.opacity}" oninput="saveWatermarkConfig()"><small id="wm-tile-opacity-label">${wm.tileOpacity||wm.opacity}%</small></label>
</div>
<div style="background:#f8f9fa;border:1px solid #e2e8f0;border-radius:7px;padding:14px">
<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px"><b>预览效果</b><button class="btn small" onclick="refreshWatermarkPreview()">↻ 刷新预览</button></div>
<div id="wm-preview" style="aspect-ratio:3/4;background:linear-gradient(135deg,#2c5560,#102a35);border-radius:5px;position:relative;overflow:hidden;max-width:420px;margin:auto">
<div id="wm-preview-canvas-wrap" style="position:absolute;inset:0"></div>
</div>
</div>
<label>生成配置代码（复制到 wechat/js/config.js 的 WATERMARK 对象中）
<textarea id="wm-code" rows="18" readonly onclick="this.select();document.execCommand('copy');toast('配置代码已复制到剪贴板')" style="font-family:monospace;font-size:12px;cursor:pointer;line-height:1.5" title="点击即可复制"></textarea>
<small style="color:#68717d">提示：点击上方代码框可直接复制全部代码</small>
</label>
</section>
</div>`;refreshWatermarkCode();refreshWatermarkPreview()}

const baseShowSeriesModal=showSeriesModal;
const baseRenderEditor=renderEditor;
renderEditor=function(){
  baseRenderEditor();
  const editorHead=document.querySelector(".editor-left .editor-head");
  if(editorHead){
    editorHead.insertAdjacentHTML("afterbegin",`<button type="button" class="btn ghost editor-back" onclick="returnFromEditor()">← 返回</button>`);
  }
  if(state.level?.mode==="image_puzzle"){
    const puzzleTitle=[...document.querySelectorAll(".editor-left .panel-title")].find(x=>x.textContent.trim()==="拼图设置");
    if(puzzleTitle){
      const asset=state.level.assets?.image||{},section=document.createElement("div");section.className="panel-section";
      section.innerHTML=`<div class="panel-title">关卡图片</div><div class="asset-picker-summary">${asset.url?`<img src="${escapeHtml(asset.thumbnail?.url||asset.thumbnail_url||asset.url)}"><small>${escapeHtml(asset.asset_id||"已选择图片")}</small>`:'<div class="empty" style="padding:12px">尚未选择图片</div>'}</div><div class="actions"><button class="btn small" onclick="openLevelAssetPicker()">从素材库选择</button><button class="btn small primary" onclick="$('level-image-file').click()">直接上传</button></div><input id="level-image-file" type="file" accept="image/png,image/jpeg" hidden onchange="uploadLevelImage(this.files[0])">`;
      puzzleTitle.closest(".panel-section").before(section);
    }
  }
  if(state.series?.id!=="daily_task")return;
  const stack=$("level-difficulty")?.closest(".form-stack");
  if(!stack)return;
  const dateLabel=document.createElement("label");
  dateLabel.innerHTML=`挑战日期<input id="level-available-date" type="date" value="${escapeHtml(state.level.available_date||new Date().toISOString().slice(0,10))}" onchange="updateLevelField('available_date',this.value)">`;
  stack.appendChild(dateLabel);
}
function returnFromEditor(){
  if(state.dirty&&!confirm("当前关卡有未保存修改，确定直接返回吗？"))return;
  state.dirty=false;
  setSave("已同步",false);
  if(state.series?.id)openSeries(state.series.id);else renderLevels();
}
showSeriesModal=function(id=""){
  baseShowSeriesModal(id);
  const input=$("series-cover");
  if(!input)return;
  const current=input.value;
  const label=input.closest("label");
  label.innerHTML=`<span>系列封面</span><input id="series-cover" type="hidden" value="${escapeHtml(current)}">
    <div class="cover-picker-current">
      <img id="series-cover-preview" src="${escapeHtml(current)}" alt="封面预览">
      <div><b id="series-cover-state">${current?"已选择封面":"尚未选择封面"}</b><small>推荐 5:3，最低 1000×600，PNG/JPG，最大 15 MB</small>
      <div class="actions"><button class="btn small" type="button" onclick="openCoverLibraryDialog()">从素材库选择</button><button class="btn small primary" type="button" onclick="$('series-cover-file').click()">直接上传</button></div></div>
      <input id="series-cover-file" type="file" accept="image/png,image/jpeg" hidden onchange="uploadSeriesCover(this.files[0])">
    </div>`;
}
function coverLibraryItems(){
  return state.assets.map(a=>`<button type="button" class="cover-asset" data-search="${escapeHtml(String(a.name||"").toLowerCase())}" onclick="selectSeriesCover('${escapeHtml(a.url)}')" title="${escapeHtml(a.name)}"><img src="${escapeHtml(a.thumbnail_url||a.url)}" loading="lazy"><span>${escapeHtml(a.name)}</span></button>`).join("")||`<div class="empty">素材库为空，请直接上传第一张封面</div>`;
}
function openCoverLibraryDialog(){
  closeCoverLibraryDialog();
  document.body.insertAdjacentHTML("beforeend",`<div id="cover-library-dialog" class="cover-dialog-backdrop" onclick="if(event.target===this)closeCoverLibraryDialog()">
    <section class="cover-dialog" role="dialog" aria-modal="true" aria-labelledby="cover-dialog-title">
      <header class="modal-header"><div><h2 id="cover-dialog-title">从素材库选择封面</h2><small>请选择符合 5:3、最低 1000×600 的图片</small></div><button type="button" class="btn ghost" onclick="closeCoverLibraryDialog()">✕</button></header>
      <div class="cover-dialog-toolbar"><input id="cover-library-search" type="search" placeholder="搜索素材文件名…" oninput="filterCoverLibrary(this.value)" autofocus><span id="cover-search-count">${state.assets.length} 个素材</span></div>
      <div class="cover-dialog-scroll">${coverLibraryItems()}</div>
      <footer class="modal-footer"><span>共 ${state.assets.length} 个素材</span><button type="button" class="btn" onclick="closeCoverLibraryDialog()">取消</button></footer>
    </section>
  </div>`);
  $("cover-library-search").focus();
}
function closeCoverLibraryDialog(){$("cover-library-dialog")?.remove()}
function openLevelAssetPicker(){
  closeLevelAssetPicker();
  document.body.insertAdjacentHTML("beforeend",`<div id="level-asset-dialog" class="cover-dialog-backdrop" onclick="if(event.target===this)closeLevelAssetPicker()"><section class="cover-dialog" role="dialog" aria-modal="true"><header class="modal-header"><div><h2>选择关卡图片</h2><small>从素材库选择一张图片作为拼图原图</small></div><button type="button" class="btn ghost" onclick="closeLevelAssetPicker()">✕</button></header><div class="cover-dialog-toolbar"><input type="search" placeholder="搜索素材…" oninput="filterLevelAssets(this.value)"><button class="btn small primary" onclick="closeLevelAssetPicker();$('level-image-file').click()">上传新图片</button></div><div class="cover-dialog-scroll">${state.assets.map((a,i)=>`<button type="button" class="cover-asset level-asset-option" data-search="${escapeHtml(String(a.name||"").toLowerCase())}" onclick="selectLevelAsset(${i})"><img src="${escapeHtml(a.thumbnail_url||a.url)}" loading="lazy"><span>${escapeHtml(a.name||a.asset_id)}</span></button>`).join("")||'<div class="empty">素材库为空，请上传第一张图片</div>'}</div></section></div>`);
}
function closeLevelAssetPicker(){$("level-asset-dialog")?.remove()}
function filterLevelAssets(value){const q=String(value||"").trim().toLowerCase();document.querySelectorAll(".level-asset-option").forEach(x=>x.hidden=!x.dataset.search.includes(q))}
async function selectLevelAsset(index){
  const asset=state.assets[index];if(!asset)return;
  let width=Number(asset.width||0),height=Number(asset.height||0);
  if(!width||!height){try{const size=await new Promise((resolve,reject)=>{const image=new Image();image.onload=()=>resolve({width:image.naturalWidth,height:image.naturalHeight});image.onerror=()=>reject(new Error("无法读取图片尺寸"));image.src=asset.url});width=size.width;height=size.height}catch(e){return toast(e.message,"error")}}
  state.level.assets=state.level.assets||{};state.level.assets.image={asset_id:asset.asset_id||String(asset.name||"asset_image").replace(/\.[^.]+$/,""),url:asset.url,sha256:asset.sha256||"",bytes:Number(asset.bytes||1),content_type:asset.content_type||(/\.jpe?g$/i.test(asset.name||"")?"image/jpeg":"image/png")};state.level.assets.width=width;state.level.assets.height=height;closeLevelAssetPicker();markDirty();renderEditor();toast("关卡图片已选择");
}
async function uploadLevelImage(file){if(!file)return;if(!["image/png","image/jpeg"].includes(file.type))return toast("仅支持 PNG 或 JPG","error");if(file.size>15*1024*1024)return toast("图片不能超过 15 MB","error");try{const size=await readImageSize(file),asset=await api(`/assets/level_image_${Date.now()}`,{method:"POST",headers:{"Content-Type":file.type},body:file});state.level.assets=state.level.assets||{};state.level.assets.image={asset_id:asset.asset_id,url:asset.url,sha256:asset.sha256,bytes:asset.bytes,content_type:asset.content_type,thumbnail:asset.thumbnail};state.level.assets.width=size.width;state.level.assets.height=size.height;await loadData();markDirty();renderEditor();toast("图片上传并选择成功")}catch(e){toast(e.message,"error")}}
function filterCoverLibrary(value){
  const query=value.trim().toLowerCase();
  let visible=0;
  document.querySelectorAll("#cover-library-dialog .cover-asset").forEach(item=>{item.hidden=!item.dataset.search.includes(query);if(!item.hidden)visible++});
  $("cover-search-count").textContent=`找到 ${visible} 个素材`;
}
async function selectSeriesCover(url){
  try{
    const size=await new Promise((resolve,reject)=>{const image=new Image();image.onload=()=>resolve({width:image.naturalWidth,height:image.naturalHeight});image.onerror=()=>reject(new Error("无法读取素材尺寸"));image.src=url});
    const ratio=size.width/size.height;
    if(size.width<1000||size.height<600)return toast(`该素材至少需要 1000×600，当前为 ${size.width}×${size.height}`,"error");
    if(Math.abs(ratio-5/3)>.035)return toast(`该素材不是 5:3，当前为 ${size.width}×${size.height}`,"error");
  }catch(e){return toast(e.message,"error")}
  $("series-cover").value=url;
  $("series-cover-preview").src=url;
  $("series-cover-state").textContent="已选择素材库封面";
  closeCoverLibraryDialog();
}
async function readImageSize(file){
  return await new Promise((resolve,reject)=>{const image=new Image(),url=URL.createObjectURL(file);image.onload=()=>{URL.revokeObjectURL(url);resolve({width:image.naturalWidth,height:image.naturalHeight})};image.onerror=()=>{URL.revokeObjectURL(url);reject(new Error("无法读取图片"))};image.src=url});
}
async function uploadSeriesCover(file){
  if(!file)return;
  if(!["image/png","image/jpeg"].includes(file.type))return toast("封面仅支持 PNG 或 JPG","error");
  if(file.size>15*1024*1024)return toast("封面不能超过 15 MB","error");
  try{
    const size=await readImageSize(file),ratio=size.width/size.height;
    if(size.width<1000||size.height<600)return toast(`封面至少需要 1000×600，当前为 ${size.width}×${size.height}`,"error");
    if(Math.abs(ratio-5/3)>.035)return toast(`封面必须为 5:3，当前为 ${size.width}×${size.height}`,"error");
    $("series-cover-state").textContent="正在上传…";
    const asset=await api(`/assets/series_cover_${Date.now()}`,{method:"POST",headers:{"Content-Type":file.type},body:file});
    await loadData();
    await selectSeriesCover(asset.url);
    $("series-cover-state").textContent=`上传成功 · ${size.width}×${size.height}`;
    toast("封面已上传并加入素材库");
  }catch(e){$("series-cover-state").textContent="上传失败";toast(e.message,"error")}
}

const WM_KEY="oddspot_admin_watermark_v1";
function getWatermarkConfig(){
  const def={enabled:true,mode:"corner",text:"内容由 AI 生成",placement:"top-right",size:22,
    margin:18,px:16,py:10,radius:10,color:"#ffffff",opacity:88,
    bgcolor:"#0b1b29",bgopacity:58,bordercolor:"#e6b95c",borderopacity:55,
    angle:-25,mx:40,my:60,tileColor:"#ffffff",tileOpacity:45};
  try{return Object.assign({},def,JSON.parse(localStorage.getItem(WM_KEY)||"{}"))}catch(_){return def}
}
function saveWatermarkConfig(){
  const mode=$("wm-mode").value;
  const base={
    enabled:$("wm-enabled").checked,
    mode,
    text:$("wm-text").value,
    placement:$("wm-placement").value,
    size:Number($("wm-size").value)||22,
  };
  if(mode==="corner"){Object.assign(base,{
    margin:Number($("wm-margin").value)||18,
    px:Number($("wm-px").value)||16,
    py:Number($("wm-py").value)||10,
    radius:Number($("wm-radius").value)||10,
    color:$("wm-color").value||"#ffffff",
    opacity:Number($("wm-opacity").value)||88,
    bgcolor:$("wm-bgcolor").value||"#0b1b29",
    bgopacity:Number($("wm-bgopacity").value)||58,
    bordercolor:$("wm-bordercolor").value||"#e6b95c",
  })}else{Object.assign(base,{
    angle:Number($("wm-angle").value)||-25,
    mx:Number($("wm-mx").value)||40,
    my:Number($("wm-my").value)||60,
    tileColor:$("wm-tile-color").value||"#ffffff",
    tileOpacity:Number($("wm-tile-opacity").value)||45,
  })}
  localStorage.setItem(WM_KEY,JSON.stringify(base));
  const op=$("wm-opacity-label"),bgop=$("wm-bgopacity-label"),top=$("wm-tile-opacity-label");
  if(op)op.textContent=`${base.opacity??0}%`;
  if(bgop)bgop.textContent=`${base.bgopacity??0}%`;
  if(top)top.textContent=`${base.tileOpacity??0}%`;
  refreshWatermarkCode();refreshWatermarkPreview();
}
function rgbFromHex(hex){
  const h=String(hex||"#ffffff").replace("#","");
  const v=h.length===3?h.split("").map(c=>c+c).join(""):h;
  const n=parseInt(v,16);
  return{r:(n>>16)&255,g:(n>>8)&255,b:n&255};
}
function rgba(hex,opacity0_100,fallback){
  try{const rgb=rgbFromHex(hex);return `rgba(${rgb.r},${rgb.g},${rgb.b},${(Math.max(0,Math.min(100,Number(opacity0_100)||0))/100).toFixed(2)})`}
  catch(_){return fallback||"rgba(255,255,255,0.5)"}
}
function refreshWatermarkCode(){
  if(!$("wm-code"))return;
  const c=getWatermarkConfig();
  const lines=["  WATERMARK: {",
    `    ENABLED: ${c.enabled},`,
    `    MODE: '${c.mode}',`,
    `    TEXT: ${JSON.stringify(c.text||"内容由 AI 生成")},`,
  ];
  if(c.mode==="corner"){
    const cornerShadow = (Math.max(0,Math.min(100,Number(c.opacity)||0))*.7/100).toFixed(2)
    lines.push(
      `    PLACEMENT: '${c.placement||"top-right"}',`,
      `    FONT_SIZE: ${c.size},`,
      `    COLOR: '${rgba(c.color,c.opacity,"rgba(255,255,255,0.88)")}',`,
      `    SHADOW_COLOR: 'rgba(0,0,0,${cornerShadow})',`,
      `    BG_COLOR: '${rgba(c.bgcolor,c.bgopacity,"rgba(11,27,41,0.58)")}',`,
      `    BORDER_COLOR: '${rgba(c.bordercolor,55,"rgba(230,185,92,0.55)")}',`,
      `    RADIUS: ${c.radius},`,
      `    PADDING_X: ${c.px},`,
      `    PADDING_Y: ${c.py},`,
      `    MARGIN: ${c.margin},`,
    )
  }
  lines.push("    TILE: {");
  const tileShadow = (Math.max(0,Math.min(100,Number(c.tileOpacity||c.opacity)||0))*.6/100).toFixed(2)
  lines.push(
    `      ANGLE: ${c.angle},`,
    `      MARGIN_X: ${c.mx},`,
    `      MARGIN_Y: ${c.my},`,
    `      COLOR: '${rgba(c.tileColor||c.color,c.tileOpacity||c.opacity,"rgba(255,255,255,0.45)")}',`,
    `      SHADOW_COLOR: 'rgba(0,0,0,${tileShadow})',`,
  );
  lines.push("    },");
  lines.push("  },");
  $("wm-code").value=lines.join("\n");
}
function drawCornerPreview(ctx,w,h,cfg){
  if(!cfg.enabled||!cfg.text)return;
  const text=String(cfg.text);
  const fontSize=cfg.size*.55;
  ctx.save();ctx.beginPath();ctx.rect(0,0,w,h);ctx.clip();
  ctx.font=`bold ${fontSize}px "Microsoft YaHei",sans-serif`;
  const metrics=ctx.measureText(text);
  const textW=metrics.width,textH=fontSize;
  const padX=(cfg.px||16)*.55,padY=(cfg.py||10)*.55;
  const boxW=textW+padX*2,boxH=textH+padY*2;
  const edge=(cfg.margin||18)*.55;
  const radius=Math.min((cfg.radius||10)*.55,boxW/2,boxH/2);
  const placements=[];
  const p=cfg.placement||"top-right";
  if(p==="four-corners")placements.push("top-right","top-left","bottom-right","bottom-left");
  else placements.push(p);
  for(const placement of placements){
    let bx,by;
    if(placement==="top-right"){bx=w-boxW-edge;by=edge}
    else if(placement==="top-left"){bx=edge;by=edge}
    else if(placement==="bottom-right"){bx=w-boxW-edge;by=h-boxH-edge}
    else if(placement==="bottom-left"){bx=edge;by=h-boxH-edge}
    else{bx=w-boxW-edge;by=edge}
    ctx.beginPath();
    ctx.moveTo(bx+radius,by);
    ctx.arcTo(bx+boxW,by,bx+boxW,by+boxH,radius);
    ctx.arcTo(bx+boxW,by+boxH,bx,by+boxH,radius);
    ctx.arcTo(bx,by+boxH,bx,by,radius);
    ctx.arcTo(bx,by,bx+boxW,by,radius);
    ctx.closePath();
    ctx.fillStyle=rgba(cfg.bgcolor,cfg.bgopacity,"rgba(11,27,41,0.58)");ctx.fill();
    ctx.strokeStyle=rgba(cfg.bordercolor,55,"rgba(230,185,92,0.55)");ctx.lineWidth=1.2;ctx.stroke();
    const tx=bx+padX,ty=by+padY+textH*0.08;
    ctx.textAlign="left";ctx.textBaseline="top";
    ctx.shadowColor="rgba(0,0,0,0.55)";ctx.shadowBlur=3;
    ctx.fillStyle=rgba(cfg.color,cfg.opacity,"rgba(255,255,255,0.88)");
    ctx.fillText(text,tx,ty);
  }
  ctx.restore();
}
function drawTilePreview(ctx,w,h,cfg){
  if(!cfg.enabled||!cfg.text)return;
  const rgb=rgbFromHex(cfg.tileColor||cfg.color);
  const op=Number(cfg.tileOpacity||cfg.opacity)||45;
  const text=String(cfg.text);
  const fontSize=cfg.size*.55;
  ctx.save();ctx.beginPath();ctx.rect(0,0,w,h);ctx.clip();
  ctx.font=`bold ${fontSize}px "Microsoft YaHei",sans-serif`;
  const metrics=ctx.measureText(text);
  const textW=metrics.width,textH=fontSize*1.4;
  const stepX=textW+(cfg.mx||40)*.55,stepY=textH+(cfg.my||60)*.55;
  const diag=Math.hypot(w,h);
  const rows=Math.ceil(diag/stepY)+2,cols=Math.ceil(diag/stepX)+2;
  ctx.translate(w/2,h/2);ctx.rotate(((cfg.angle||-25))*Math.PI/180);
  ctx.fillStyle=`rgba(${rgb.r},${rgb.g},${rgb.b},${(op/100).toFixed(2)})`;
  ctx.shadowColor=`rgba(0,0,0,${Math.min(.5,op*.6/100).toFixed(2)})`;ctx.shadowBlur=2;
  ctx.textAlign="center";ctx.textBaseline="middle";
  for(let r=-rows;r<=rows;r+=1){for(let c=-cols;c<=cols;c+=1){const ox=r%2===0?0:stepX/2;ctx.fillText(text,c*stepX+ox,r*stepY)}}
  ctx.restore();
}
function refreshWatermarkPreview(){
  const wrap=$("wm-preview-canvas-wrap");if(!wrap)return;
  wrap.innerHTML="";
  const cfg=getWatermarkConfig();
  const canvas=document.createElement("canvas");
  const parent=$("wm-preview");if(!parent)return;
  const rect=parent.getBoundingClientRect();
  const scale=window.devicePixelRatio||1;
  canvas.style.width="100%";canvas.style.height="100%";canvas.style.display="block";
  canvas.width=Math.max(300,Math.round(rect.width*scale));
  canvas.height=Math.max(400,Math.round(rect.height*scale));
  wrap.appendChild(canvas);
  const ctx=canvas.getContext("2d");
  ctx.setTransform(scale,0,0,scale,0,0);
  const w=rect.width,h=rect.height;
  const bg=ctx.createLinearGradient(0,0,w,h);
  bg.addColorStop(0,"#d3b98a");bg.addColorStop(1,"#9a7a52");
  ctx.fillStyle=bg;ctx.fillRect(0,0,w,h);
  ctx.fillStyle="#c2a679";ctx.fillRect(w*.08,h*.12,w*.35,h*.22);
  ctx.fillStyle="#7a5f3e";ctx.fillRect(w*.55,h*.55,w*.32,h*.28);
  ctx.fillStyle="#b59368";ctx.fillRect(w*.12,h*.58,w*.28,h*.24);
  ctx.fillStyle="#5a462f";ctx.beginPath();ctx.arc(w*.28,h*.26,w*.07,0,Math.PI*2);ctx.fill();
  ctx.fillStyle="#6b5341";ctx.fillRect(w*.7,h*.15,w*.22,h*.04);
  cfg.mode==="corner"?drawCornerPreview(ctx,w,h,cfg):drawTilePreview(ctx,w,h,cfg);
}
window.addEventListener("resize",()=>{if(state.view==="settings")refreshWatermarkPreview()});

saveLevel=async function(status){try{const l=state.level;if(status==="published"&&l.mode==="find_anachronism"){if((l.differences||[]).length<3)throw new Error("找穿帮关卡至少需要 3 个答案");const incomplete=l.differences.find(x=>!String(x.era||"").trim()||String(x.explanation||"").trim().length<20);if(incomplete)throw new Error(`答案“${incomplete.label||incomplete.id}”需要填写线索和至少20字的线索推理`)}if(status==="published"&&l.mode==="image_puzzle"&&!(l.puzzle?.rows>=2&&l.puzzle?.cols>=2))throw new Error("发布拼图关卡前请设置有效的行列数");setSave("保存中…");l.instruction=l.mode==="image_puzzle"?"随机打乱拼块，还原完整画面":`圈出 ${l.differences.length} 个不属于这个年代的物件`;l.level_version=Number(l.level_version||1)+1;const seriesId=$("editor-series")?.value||state.series.id;await api(`/levels/${encodeURIComponent(l.level_id)}`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({series_id:seriesId,sort_order:state.levelEntry?.sort_order||10,status,runtime_json:l})});setSave("已保存",false);toast(status==="published"?"关卡已发布":"草稿已保存");await loadData();state.series=state.catalog.find(s=>s.id===seriesId);state.levelEntry=state.series?.levels.find(x=>x.id===l.level_id);renderEditor()}catch(e){setSave("保存失败",true);toast(e.message,"error")}};
showPublishModal=function(){const l=state.level,d=l.differences||[],p=l.puzzle,valid=l.mode==="image_puzzle"?!!(p&&p.rows>=2&&p.cols>=2):d.length>=3&&d.every(x=>x.id&&x.label&&x.era&&String(x.explanation||"").trim().length>=20),summary=l.mode==="image_puzzle"?`${p?.rows||0}×${p?.cols||0} 网格，共 ${(p?.rows||0)*(p?.cols||0)} 块（客户端随机打乱）`:`${d.length} 个答案热点`;$("modal-root").innerHTML=`<div class="modal-backdrop"><div class="modal"><div class="modal-header"><h2>发布关卡</h2><button class="btn ghost" onclick="closeModal()">✕</button></div><div class="modal-body"><p><b>${escapeHtml(l.title)}</b></p><div class="checks"><div class="check">✓ 图片资源已配置</div><div class="check">✓ ${summary}</div><div class="check">${valid?"✓":"⚠"} 发布校验</div></div></div><div class="modal-footer"><button class="btn" onclick="closeModal()">取消</button><button class="btn primary" ${valid?"":"disabled"} onclick="closeModal();saveLevel('published')">确认并发布</button></div></div></div>`};
showMobilePreview=function(){const a=state.level.assets.image;$("modal-root").innerHTML=`<div class="modal-backdrop"><div class="modal"><div class="modal-header"><h2>手机玩家预览</h2><button class="btn ghost" onclick="closeModal()">✕</button></div><div class="modal-body"><div class="mobile-preview"><div class="mobile-top"><span>‹</span><b>${escapeHtml(state.level.title)}</b><span>💡</span></div>${state.level.mode==="image_puzzle"?`<canvas id="puzzle-admin-canvas" data-src="${escapeHtml(a.url||a.local_path)}" style="width:100%"></canvas>`:`<div style="position:relative"><img src="${escapeHtml(a.url||a.local_path)}">${hotspots()}</div>`}</div></div></div></div>`;if(state.level.mode==="image_puzzle")drawPuzzleAdmin()};

document.querySelectorAll(".nav-item").forEach(x=>x.onclick=()=>navigate(x.dataset.view));
$("api-base").value=apiBase();
$("logout").onclick=()=>{clearAdminSession();location.reload()};
$("login-form").onsubmit=async event=>{event.preventDefault();saveAdminSession($("token").value);localStorage.setItem("oddspot_admin_api",$("api-base").value.replace(/\/$/,""));try{await loadData();$("login").classList.add("hidden");renderOverview()}catch(e){clearAdminSession();toast(e.message,"error")}};
window.addEventListener("beforeunload",e=>{if(state.dirty){e.preventDefault();e.returnValue=""}});
if(token())loadData().then(()=>{$("login").classList.add("hidden");renderOverview()}).catch(()=>clearAdminSession());
